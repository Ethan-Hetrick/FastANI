/**
 * @file    parseCmdArgs.hpp
 * @brief   Functionality related to command line parsing for indexing and mapping
 * @author  Chirag Jain <cjain7@gatech.edu>
 */

#ifndef PARSE_CMD_HPP
#define PARSE_CMD_HPP

#include <iostream>
#include <string>
#include <fstream>
#include <cassert>
#include <map>
#include <tuple>
#include <limits>

// Own includes
#include "map/include/map_parameters.hpp"
#include "map/include/map_stats.hpp"
#include "map/include/commonFunc.hpp"

// External includes
#include "common/clipp.h"
#include "common/kseq.h"
#include <zlib.h>

namespace skch
{

/**
 * @brief                   Parse the file which has list of reference or query files
 * @param[in]   fileToRead  File containing list of ref/query files
 * @param[out]  fileList    List of files will be saved in this vector
 */
template <typename VEC> void parseFileList(std::string &fileToRead, VEC &fileList)
{
  std::string line;

  std::ifstream in(fileToRead);

  if (in.fail())
  {
    std::cerr << "ERROR, skch::parseFileList, Could not open " << fileToRead << "\n";
    exit(1);
  }

  while (std::getline(in, line))
  {
    // trim whitespaces
    skch::CommonFunc::trim(line);

    if (line.length() > 0) // avoid empty strings
      fileList.push_back(line);
  }
}

/**
 * @brief                     validate the reference and query file(s)
 * @param[in] querySequences  vector containing query file names
 * @param[in] refSequences    vector containing reference file names
 */
template <typename VEC> void validateInputFiles(VEC &querySequences, VEC &refSequences)
{
  if (refSequences.size() == 0)
  {
    std::cerr << "ERROR, skch::validateInputFiles, Count of ref genomes should be non-zero"
              << std::endl;
    exit(1);
  }

  // Open file one by one
  for (auto &e : querySequences)
  {
    std::ifstream in(e);

    if (in.fail())
    {
      std::cerr << "ERROR, skch::validateInputFiles, Could not open " << e << std::endl;
      exit(1);
    }
  }

  for (auto &e : refSequences)
  {
    std::ifstream in(e);

    if (in.fail())
    {
      std::cerr << "ERROR, skch::validateInputFiles, Could not open " << e << std::endl;
      exit(1);
    }
  }
}

template <typename VEC> void warnOnDuplicateInputPaths(const VEC &paths, const std::string &label)
{
  std::map<std::string, int> counts;
  for (const auto &path : paths)
    counts[path]++;

  for (const auto &entry : counts)
  {
    if (entry.second > 1)
    {
      std::cerr << "WARNING, duplicate " << label << " input path appears " << entry.second
                << " times: " << entry.first << std::endl;
    }
  }
}

struct ReferenceSketchSortKey
{
  std::uint64_t usableGenomeLength = 0;
  std::uint64_t contigCount = 0;
  hash_t smallestMinimizerHash = std::numeric_limits<hash_t>::max();
  std::string originalPath;
};

inline ReferenceSketchSortKey buildReferenceSketchSortKey(const std::string &fileName,
                                                          const skch::Parameters &parameters)
{
  ReferenceSketchSortKey key;
  key.originalPath = fileName;

  gzFile fp = gzopen(fileName.c_str(), "r");
  if (fp == Z_NULL)
  {
    std::cerr << "ERROR, skch::buildReferenceSketchSortKey, Could not open " << fileName
              << std::endl;
    exit(1);
  }

  gzbuffer(fp, 1 << 20);
  kseq_t *seq = kseq_init(fp);
  offset_t len = 0;

  while ((len = kseq_read(seq)) >= 0)
  {
    key.contigCount++;
    key.usableGenomeLength +=
      (static_cast<std::uint64_t>(len) / static_cast<std::uint64_t>(parameters.minReadLength)) *
      static_cast<std::uint64_t>(parameters.minReadLength);

    if (len >= parameters.windowSize && len >= parameters.kmerSize)
    {
      key.smallestMinimizerHash =
        std::min(key.smallestMinimizerHash,
                 skch::CommonFunc::smallestMinimizerHash(
                   seq, parameters.kmerSize, parameters.windowSize, parameters.alphabetSize));
    }
  }

  kseq_destroy(seq);
  gzclose(fp);

  return key;
}

inline void canonicalizeReferenceOrderForSketchWrite(skch::Parameters &parameters)
{
  std::vector<std::pair<ReferenceSketchSortKey, std::string>> keyedReferences;
  keyedReferences.reserve(parameters.refSequences.size());
  std::map<std::tuple<std::uint64_t, std::uint64_t, hash_t>, std::vector<std::string>>
    potentialDuplicates;

  for (const auto &ref : parameters.refSequences)
  {
    auto key = buildReferenceSketchSortKey(ref, parameters);
    potentialDuplicates[std::make_tuple(key.usableGenomeLength, key.contigCount,
                                        key.smallestMinimizerHash)]
      .push_back(ref);
    keyedReferences.push_back({key, ref});
  }

  for (const auto &entry : potentialDuplicates)
  {
    if (entry.second.size() > 1)
    {
      std::cerr << "WARNING, sketch creation found potentially identical reference inputs based "
                   "on (usable_genome_length, contig_count, smallest_minimizer_hash): "
                << entry.second << std::endl;
    }
  }

  std::stable_sort(keyedReferences.begin(), keyedReferences.end(),
                   [](const auto &lhs, const auto &rhs)
                   {
                     const auto &a = lhs.first;
                     const auto &b = rhs.first;
                     return std::tie(a.usableGenomeLength, a.contigCount, a.smallestMinimizerHash,
                                     a.originalPath) < std::tie(b.usableGenomeLength, b.contigCount,
                                                                b.smallestMinimizerHash,
                                                                b.originalPath);
                   });

  for (size_t i = 0; i < keyedReferences.size(); i++)
    parameters.refSequences[i] = keyedReferences[i].second;
}

/**
 * @brief                   Print the parsed cmd line options
 * @param[in]  parameters   parameters parsed from command line
 */
void printCmdOptions(skch::Parameters &parameters)
{
  std::cerr << ">>>>>>>>>>>>>>>>>>" << std::endl;
  std::cerr << "Reference = " << parameters.refSequences << std::endl;
  std::cerr << "Query = " << parameters.querySequences << std::endl;
  std::cerr << "Kmer size = " << parameters.kmerSize << std::endl;
  std::cerr << "Window size = " << parameters.windowSize << std::endl;
  std::cerr << "Reference size assumption = " << parameters.referenceSize << std::endl;
  std::cerr << "Fragment length = " << parameters.minReadLength << std::endl;
  std::cerr << "Threads = " << parameters.threads << std::endl;
  if (parameters.batchSize > 0)
    std::cerr << "Sketch batch size = " << parameters.batchSize << std::endl;
  else
    std::cerr << "Sketch batch size = all shards" << std::endl;
  if (parameters.outFileName.empty())
    std::cerr << "ANI output file = stdout" << std::endl;
  else
    std::cerr << "ANI output file = " << parameters.outFileName << std::endl;
  std::cerr << "Sanity Check  = " << parameters.sanityCheck << std::endl;
  std::cerr << ">>>>>>>>>>>>>>>>>>" << std::endl;
}

/**
 * @brief                   Parse the cmd line options
 * @param[in]   cmd
 * @param[out]  parameters  sketch parameters are saved here
 */
void parseandSave(int argc, char **argv, skch::Parameters &parameters)
{
  // defaults
  parameters.kmerSize = 16;
  parameters.windowSizeManual = 0;
  parameters.minReadLength = 3000;
  parameters.alphabetSize = 4;
  parameters.minFraction = 0.2;
  parameters.threads = 1;
  parameters.p_value = 1e-03;
  parameters.percentageIdentity = 80;
  parameters.visualize = false;
  parameters.matrixOutput = false;
  parameters.referenceSize = 5000000;
  parameters.maxRatioDiff = 100.0;
  parameters.reportAll = true; // we need all mappings per fragment, not just best 1% as in mashmap
  parameters.sanityCheck = false;
  parameters.writeRefSketchFile = "";
  parameters.writeRefSketchMode = false;
  parameters.sketchFile = "";
  parameters.loadSketchMode = false;
  parameters.batchSize = 0;

  std::string refName, refList;
  std::string qryName, qryList;
  bool versioncheck = false;
  bool help = false;

  // INPUT OPTIONS
  auto ref_cmd = (clipp::option("-r", "--ref") & clipp::value("value", refName)) %
                 "reference genome (fasta/fastq)[.gz]";
  auto refList_cmd = (clipp::option("--rl", "--refList") & clipp::value("value", refList)) %
                     "a file containing list of reference genome files, one genome per line";
  auto qry_cmd = (clipp::option("-q", "--query") & clipp::value("value", qryName)) %
                 "query genome (fasta/fastq)[.gz]";
  auto qryList_cmd = (clipp::option("--ql", "--queryList") & clipp::value("value", qryList)) %
                     "a file containing list of query genome files, one genome per line";
  auto sketch_cmd = (clipp::option("--sketch") & clipp::value("value", parameters.sketchFile)) %
                    "load reference sketches from file prefix instead of rebuilding; use this "
                    "instead of --ref/--refList";

  // OUTPUT OPTIONS
  auto output_cmd =
    (clipp::option("-o", "--output") & clipp::value("value", parameters.outFileName)) %
    "output file name [optional; defaults to stdout for the main tabular output]";
  auto write_ref_sketch_cmd =
    (clipp::option("--write-ref-sketch") & clipp::value("value", parameters.writeRefSketchFile)) %
    "write reference sketches to file and exit; requires --ref/--refList and does not use query "
    "input";
  auto matrix_cmd =
    clipp::option("--matrix")
      .set(parameters.matrixOutput)
      .doc("also write ANI values as a lower triangular matrix to <output>.matrix; this affects "
           "matrix output only and is incompatible with --batch-size [disabled by default]");
  auto average_reciprocals_cmd =
    clipp::option("--average-reciprocals")
      .set(parameters.averageReciprocals)
      .doc("average ANI and fragment-level ANI summary metrics across reciprocal pairs in the main "
           "sparse tabular output; keeps the displayed query/reference orientation of the emitted "
           "row");
  auto visualize_cmd =
    clipp::option("--visualize")
      .set(parameters.visualize)
      .doc("also write fragment mappings to <output>.visual for downstream visualization; valid "
           "for pairwise and multi-genome runs, but the bundled R plotting example is "
           "pairwise-oriented [disabled by default]");
  auto extended_metrics_cmd =
    clipp::option("--extended-metrics")
      .set(parameters.extendedMetrics)
      .doc("report extended fragment-level ANI metrics in the tabular output only");
  auto header_cmd = clipp::option("--header")
                      .set(parameters.header)
                      .doc("write a header row in the tabular output only; does not affect "
                           "--matrix or --visualize outputs");

  // MAPPING PARAMETERS
  auto kmer_cmd = (clipp::option("-k", "--kmer") & clipp::value("value", parameters.kmerSize)) %
                  "kmer size <= 16 [default : 16]";
  auto window_size_cmd =
    (clipp::option("--window-size") & clipp::value("value", parameters.windowSizeManual)) %
    "set minimizer window size manually instead of using the internally recommended value";
  auto reference_size_cmd =
    (clipp::option("--reference-size") & clipp::value("value", parameters.referenceSize)) %
    "reference size assumption used for automatic window-size selection; default is 5,000,000 bp "
    "as a rough average bacterial genome size";
  auto fraglen_cmd =
    (clipp::option("--fragLen") & clipp::value("value", parameters.minReadLength)) %
    "fragment length [default : 3,000]";
  auto minfraction_cmd =
    (clipp::option("--minFraction") & clipp::value("value", parameters.minFraction)) %
    "minimum fraction of genome that must be shared for trusting ANI. If reference and query "
    "genome size differ, smaller one among the two is considered. [default : 0.2]";
  auto maxratio_cmd =
    (clipp::option("--maxRatioDiff") & clipp::value("value", parameters.maxRatioDiff)) %
    "maximum difference between (Total Ref. Length/Total Occ. Hashes) and (Total Ref. Length/Total "
    "No. Hashes). [default : 10.0]";

  // EXECUTION OPTIONS
  auto thread_cmd = (clipp::option("-t", "--threads") & clipp::value("value", parameters.threads)) %
                    "thread count for parallel execution [default : 1]";
  auto batch_size_cmd =
    (clipp::option("--batch-size") & clipp::value("value", parameters.batchSize)) %
    "load sketch shards in batches during sketch-backed querying; requires --sketch. Use 1 for the "
    "lowest memory footprint, intermediate values for a memory/runtime tradeoff, and omit it to "
    "load all shards at once";
  auto sanitycheck_cmd =
    clipp::option("-s", "--sanityCheck").set(parameters.sanityCheck).doc("run sanity check");
  auto help_cmd = clipp::option("-h", "--help").set(help).doc("print this help page");
  auto version_cmd = clipp::option("-v", "--version").set(versioncheck).doc("show version");

  auto input_cli = (ref_cmd, refList_cmd, qry_cmd, qryList_cmd, sketch_cmd);

  auto output_cli = (output_cmd, write_ref_sketch_cmd, matrix_cmd, average_reciprocals_cmd,
                     visualize_cmd, extended_metrics_cmd, header_cmd);

  auto mapping_cli =
    (kmer_cmd, window_size_cmd, reference_size_cmd, fraglen_cmd, minfraction_cmd, maxratio_cmd);

  auto execution_cli = (thread_cmd, batch_size_cmd, sanitycheck_cmd, help_cmd, version_cmd);

  auto cli = (input_cli, output_cli, mapping_cli, execution_cli);

  // with formatting options
  auto fmt = clipp::doc_formatting{}.first_column(0).doc_column(5).last_column(80);

  std::string description =
    "\nfastANI is a fast alignment-free implementation for computing whole-genome Average "
    "Nucleotide Identity (ANI) between genomes\n\nEXAMPLE USAGE\n-------------\n1 vs 1 comparison "
    "with extended metrics:\n$ fastANI -q query.fa -r reference.fa --extended-metrics -o "
    "output.txt\n\nGenerate a reference sketch from a reference list:\n$ fastANI --refList "
    "references.txt --write-ref-sketch reference_sketch\n\n1 vs all comparison using a sketch with "
    "visualization output:\n$ fastANI -q query.fa --sketch reference_sketch --visualize -o "
    "output.txt\n\n1 vs all comparison using a sketch with one shard loaded at a time:\n$ fastANI "
    "-q query.fa --sketch reference_sketch --batch-size 1 -o output.txt\n\nAll vs all comparison "
    "with query list, reference list, averaged reciprocals, and visualization mappings:\n$ fastANI "
    "--queryList queries.txt --refList references.txt --average-reciprocals --visualize -o "
    "output.txt";

  auto printHelp = [&]()
  {
    auto man =
      clipp::man_page{}
        .append_section("SYNOPSIS\n--------", clipp::usage_lines(cli, argv[0], fmt).str())
        .append_section("INPUT OPTIONS\n-------------", clipp::documentation(input_cli, fmt).str())
        .append_section("OUTPUT OPTIONS\n--------------",
                        clipp::documentation(output_cli, fmt).str())
        .append_section("MAPPING PARAMETERS\n------------------",
                        clipp::documentation(mapping_cli, fmt).str())
        .append_section("EXECUTION OPTIONS\n-----------------",
                        clipp::documentation(execution_cli, fmt).str())
        .prepend_section("", description);

    clipp::operator<<(std::cout, man) << std::endl;
  };

  if (!clipp::parse(argc, argv, cli))
  {
    // print help page
    printHelp();
    exit(1);
  }

  if (help)
  {
    printHelp();
    exit(0);
  }

  if (versioncheck)
  {
    std::cerr << "version 1.33\n\n";
    exit(0);
  }

  if (!parameters.writeRefSketchFile.empty())
  {
    parameters.writeRefSketchMode = true;
  }

  if (!parameters.sketchFile.empty())
    parameters.loadSketchMode = true;

  if (parameters.batchSize != 0)
  {
    if (!parameters.loadSketchMode)
    {
      std::cerr << "ERROR, --batch-size is supported only with --sketch\n";
      exit(1);
    }

    if (parameters.writeRefSketchMode)
    {
      std::cerr << "ERROR, --batch-size cannot be used while writing reference sketches\n";
      exit(1);
    }

    if (parameters.matrixOutput)
    {
      std::cerr << "ERROR, --batch-size cannot be used with --matrix\n";
      exit(1);
    }

    if (parameters.batchSize < 1)
    {
      std::cerr << "ERROR, --batch-size must be at least 1 when provided\n";
      exit(1);
    }
  }

  if (!parameters.loadSketchMode && refName == "" && refList == "")
  {
    std::cerr << "Provide reference file (s)\n";
    exit(1);
  }

  if (!parameters.writeRefSketchMode && qryName == "" && qryList == "")
  {
    std::cerr << "Provide query file (s)\n";
    exit(1);
  }

  if (parameters.outFileName.empty() && (parameters.matrixOutput || parameters.visualize))
  {
    std::cerr << "ERROR, --matrix and --visualize require -o/--output because they write "
                 "sidecar files\n";
    exit(1);
  }

  if (!parameters.loadSketchMode)
  {
    if (refName != "")
      parameters.refSequences.push_back(refName);
    else
      parseFileList(refList, parameters.refSequences);
  }

  if (!parameters.writeRefSketchMode)
  {
    if (qryName != "")
      parameters.querySequences.push_back(qryName);
    else
      parseFileList(qryList, parameters.querySequences);
  }

  assert(parameters.minFraction >= 0.0 && parameters.minFraction <= 1.0);

  if (parameters.windowSizeManual < 0)
  {
    std::cerr << "ERROR, --window-size must be greater than 0 when provided\n";
    exit(1);
  }

  if (parameters.referenceSize < 1)
  {
    std::cerr << "ERROR, --reference-size must be at least 1 when provided\n";
    exit(1);
  }

  // Compute optimal window size
  parameters.windowSize = skch::Stat::recommendedWindowSize(
    parameters.p_value, parameters.kmerSize, parameters.alphabetSize, parameters.percentageIdentity,
    parameters.minReadLength, parameters.referenceSize);

  if (parameters.windowSizeManual > 0)
    parameters.windowSize = parameters.windowSizeManual;

  if (parameters.writeRefSketchMode)
  {
    std::vector<std::string> emptyQueries;
    validateInputFiles(emptyQueries, parameters.refSequences);
  }
  else if (parameters.loadSketchMode)
  {
    for (auto &e : parameters.querySequences)
    {
      std::ifstream in(e);
      if (in.fail())
      {
        std::cerr << "ERROR, skch::validateInputFiles, Could not open " << e << std::endl;
        exit(1);
      }
    }
  }
  else
  {
    validateInputFiles(parameters.querySequences, parameters.refSequences);
  }

  warnOnDuplicateInputPaths(parameters.querySequences, "query");
  warnOnDuplicateInputPaths(parameters.refSequences, "reference");

  if (parameters.writeRefSketchMode)
    canonicalizeReferenceOrderForSketchWrite(parameters);

  printCmdOptions(parameters);
}
} // namespace skch

#endif
