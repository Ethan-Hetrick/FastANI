/**
 * @file    computeCoreIdentity.hpp
 * @author  Chirag Jain <cjain7@gatech.edu>
 */

#ifndef CGI_IDENTITY_HPP
#define CGI_IDENTITY_HPP

#include <vector>
#include <algorithm>
#include <unordered_map>
#include <fstream>
#include <iostream>
#include <cmath>
#include <omp.h>
#include <zlib.h>

// Own includes
#include "map/include/base_types.hpp"
#include "cgi/include/cgid_types.hpp"

// External includes
#include "common/kseq.h"
#include "common/prettyprint.hpp"

namespace cgi
{
/**
 * @brief                       Use reference sketch's sequence to file (genome) mapping
 *                              and revise reference ids to genome id
 * @param[in/out] shortResults
 */
void reviseRefIdToGenomeId(std::vector<MappingResult_CGI> &shortResults, skch::Sketch &refSketch)
{
  static thread_local std::vector<int> contigToGenomeId;

  const size_t numContigs = refSketch.metadata.size();

  if (contigToGenomeId.size() != numContigs)
  {
    contigToGenomeId.assign(numContigs, -1);

    size_t start = 0;
    for (size_t genomeId = 0; genomeId < refSketch.sequencesByFileInfo.size(); genomeId++)
    {
      const size_t end = static_cast<size_t>(refSketch.sequencesByFileInfo[genomeId]);

      for (size_t contigId = start; contigId < end && contigId < numContigs; contigId++)
      {
        contigToGenomeId[contigId] = static_cast<int>(genomeId);
      }

      start = end;
    }
  }

  for (auto &r : shortResults)
  {
    const size_t contigId = static_cast<size_t>(r.refSequenceId);

    if (contigId < contigToGenomeId.size())
      r.genomeId = contigToGenomeId[contigId];
  }
}

/**
 * @brief                       compute genome lengths in reference and query genome set
 * @param[out] genomeLengths
 */
void computeGenomeLengths(skch::Parameters &parameters,
                          std::unordered_map<std::string, uint64_t> &genomeLengths)
{
  for (auto &e : parameters.querySequences)
  {
    // Open the file using kseq
    gzFile fp = gzopen(e.c_str(), "r");
    gzbuffer(fp, 1 << 20); // 1MB read buffer
    kseq_t *seq = kseq_init(fp);
    int l;
    uint64_t genomeLen = 0;

    while ((l = kseq_read(seq)) >= 0)
    {
      if (l >= parameters.minReadLength)
      {
        uint64_t _l_ =
          (((uint64_t)seq->seq.l) / parameters.minReadLength) * parameters.minReadLength;
        genomeLen = genomeLen + _l_;
      }
    }

    genomeLengths[e] = genomeLen;

    kseq_destroy(seq);
    gzclose(fp); // close the file handler
  }

  if (parameters.loadSketchMode)
  {
    for (size_t i = 0; i < parameters.refSequences.size(); i++)
    {
      uint64_t genomeLen = 0;

      if (i < parameters.refSequenceLengths.size())
        genomeLen = parameters.refSequenceLengths[i];

      genomeLengths[parameters.refSequences[i]] = genomeLen;
    }
  }
  else
  {
    for (auto &e : parameters.refSequences)
    {
      if (genomeLengths.find(e) == genomeLengths.end())
      {
        gzFile fp = gzopen(e.c_str(), "r");
        gzbuffer(fp, 1 << 20); // 1MB read buffer
        kseq_t *seq = kseq_init(fp);
        int l;
        uint64_t genomeLen = 0;

        while ((l = kseq_read(seq)) >= 0)
        {
          if (l >= parameters.minReadLength)
          {
            uint64_t _l_ =
              (((uint64_t)seq->seq.l) / parameters.minReadLength) * parameters.minReadLength;
            genomeLen = genomeLen + _l_;
          }
        }

        genomeLengths[e] = genomeLen;

        kseq_destroy(seq);
        gzclose(fp); // close the file handler
      }
    }
  }
}

/**
 * @brief                             output blast tabular mappings for visualization
 * @param[in]   parameters            algorithm parameters
 * @param[in]   results               bidirectional mappings
 * @param[in]   mapper                mapper object used for mapping
 * @param[in]   refSketch             reference sketch
 * @param[in]   queryFileNo           query genome is parameters.querySequences[queryFileNo]
 * @param[in]   fileName              file name where results will be reported
 */
void outputVisualizationFile(skch::Parameters &parameters,
                             std::vector<MappingResult_CGI> &mappings_2way, skch::Map &mapper,
                             skch::Sketch &refSketch, uint64_t queryFileNo, std::string &fileName)
{
  std::string visFileName = fileName + ".visual";
  if (omp_get_num_threads() > 1)
    visFileName += std::to_string(omp_get_thread_num());
  std::ofstream outstrm(visFileName, std::ios::app);

  // Shift offsets for converting from local (to contig) to global (to genome)
  std::vector<skch::offset_t> queryOffsetAdder(mapper.metadata.size());
  std::vector<skch::offset_t> refOffsetAdder(refSketch.metadata.size());

  for (int i = 0; i < mapper.metadata.size(); i++)
  {
    if (i == 0)
      queryOffsetAdder[i] = 0;
    else
      queryOffsetAdder[i] = queryOffsetAdder[i - 1] + mapper.metadata[i - 1].len;
  }

  for (int i = 0; i < refSketch.metadata.size(); i++)
  {
    if (i == 0)
      refOffsetAdder[i] = 0;
    else
      refOffsetAdder[i] = refOffsetAdder[i - 1] + refSketch.metadata[i - 1].len;
  }

  // Report all mappings that contribute to core-genome identity estimate
  // Format the output to blast tabular way (outfmt 6)
  for (auto &e : mappings_2way)
  {
    outstrm << parameters.querySequences[queryFileNo] << "\t" << parameters.refSequences[e.genomeId]
            << "\t" << e.nucIdentity << "\t" << "NA"
            << "\t" << "NA"
            << "\t" << "NA"
            << "\t" << e.queryStartPos + queryOffsetAdder[e.querySeqId] << "\t"
            << e.queryStartPos + parameters.minReadLength - 1 + queryOffsetAdder[e.querySeqId]
            << "\t" << e.refStartPos + refOffsetAdder[e.refSequenceId] << "\t"
            << e.refStartPos + parameters.minReadLength - 1 + refOffsetAdder[e.refSequenceId]
            << "\t" << "NA"
            << "\t" << "NA"
            << "\n";
  }
}

/**
 * @brief                             compute and report AAI/ANI
 * @param[in]   parameters            algorithm parameters
 * @param[in]   results               mapping results
 * @param[in]   mapper                mapper object used for mapping
 * @param[in]   refSketch             reference sketch
 * @param[in]   totalQueryFragments   count of total sequence fragments in query genome
 * @param[in]   queryFileNo           query genome is parameters.querySequences[queryFileNo]
 * @param[in]   fileName              file name where results will be reported
 * @param[out]  CGI_ResultsVector     FastANI results
 */

inline float percentileFromSorted(const std::vector<float> &vals, double p)
{
  if (vals.empty())
    return 0.0f;

  if (vals.size() == 1)
    return vals[0];

  double idx = p * (vals.size() - 1);
  size_t lo = static_cast<size_t>(std::floor(idx));
  size_t hi = static_cast<size_t>(std::ceil(idx));

  if (lo == hi)
    return vals[lo];

  double frac = idx - lo;
  return static_cast<float>(vals[lo] + frac * (vals[hi] - vals[lo]));
}

inline float computeStdDev(const std::vector<float> &vals, float mean)
{
  if (vals.size() <= 1)
    return 0.0f;

  double sumSq = 0.0;
  for (float v : vals)
  {
    double d = v - mean;
    sumSq += d * d;
  }

  return static_cast<float>(std::sqrt(sumSq / vals.size()));
}

struct NamedCGIResult
{
  CGI_Results result;
  std::string qryGenome;
  std::string refGenome;
  std::string pairLo;
  std::string pairHi;
};

inline CGI_Results averageReciprocalSummary(const CGI_Results &canonical, const CGI_Results &other,
                                            bool extendedMetrics)
{
  CGI_Results averaged = canonical;
  averaged.identity = (canonical.identity + other.identity) / 2.0f;

  if (extendedMetrics)
  {
    averaged.frac99 = (canonical.frac99 + other.frac99) / 2.0f;
    averaged.sdAni = (canonical.sdAni + other.sdAni) / 2.0f;
    averaged.q1Ani = (canonical.q1Ani + other.q1Ani) / 2.0f;
    averaged.medianAni = (canonical.medianAni + other.medianAni) / 2.0f;
    averaged.q3Ani = (canonical.q3Ani + other.q3Ani) / 2.0f;
  }

  return averaged;
}

inline std::vector<CGI_Results> averageReciprocalResults(skch::Parameters &parameters,
                                                         const std::vector<CGI_Results> &results)
{
  std::vector<NamedCGIResult> namedResults;
  namedResults.reserve(results.size());

  for (const auto &e : results)
  {
    std::string qryGenome = parameters.querySequences[e.qryGenomeId];
    std::string refGenome = parameters.refSequences[e.refGenomeId];

    namedResults.push_back(NamedCGIResult{e, qryGenome, refGenome, std::min(qryGenome, refGenome),
                                          std::max(qryGenome, refGenome)});
  }

  std::stable_sort(namedResults.begin(), namedResults.end(),
                   [](const NamedCGIResult &x, const NamedCGIResult &y)
                   {
                     return std::tie(x.pairLo, x.pairHi, x.qryGenome, x.refGenome,
                                     x.result.qryGenomeId, x.result.refGenomeId) <
                            std::tie(y.pairLo, y.pairHi, y.qryGenome, y.refGenome,
                                     y.result.qryGenomeId, y.result.refGenomeId);
                   });

  std::vector<CGI_Results> averagedResults;
  averagedResults.reserve(namedResults.size());

  for (size_t i = 0; i < namedResults.size();)
  {
    size_t j = i + 1;

    while (j < namedResults.size() && namedResults[j].pairLo == namedResults[i].pairLo &&
           namedResults[j].pairHi == namedResults[i].pairHi)
    {
      j++;
    }

    bool isSimpleReciprocalPair = (j - i == 2) &&
                                  namedResults[i].qryGenome == namedResults[i + 1].refGenome &&
                                  namedResults[i].refGenome == namedResults[i + 1].qryGenome;

    if (isSimpleReciprocalPair)
    {
      const NamedCGIResult &first = namedResults[i];
      const NamedCGIResult &second = namedResults[i + 1];
      bool firstIsCanonical = first.qryGenome <= first.refGenome;
      const CGI_Results &canonical = firstIsCanonical ? first.result : second.result;
      const CGI_Results &other = firstIsCanonical ? second.result : first.result;

      averagedResults.push_back(
        averageReciprocalSummary(canonical, other, parameters.extendedMetrics));
    }
    else
    {
      for (size_t k = i; k < j; k++)
        averagedResults.push_back(namedResults[k].result);
    }

    i = j;
  }

  return averagedResults;
}

void computeCGI(skch::Parameters &parameters, skch::MappingResultsVector_t &results,
                skch::Map &mapper, skch::Sketch &refSketch, uint64_t totalQueryFragments,
                uint64_t queryFileNo, std::string &fileName,
                std::vector<cgi::CGI_Results> &CGI_ResultsVector)
{
  // Vector to save relevant fields from mapping results
  std::vector<MappingResult_CGI> shortResults;

  shortResults.reserve(results.size());

  // Note to self: For debugging any issue, it is often useful to print
  // shortResults, mappings_1way and mappings_2way vectors

  /// Parse map results and save fields which we need
  // reference id (R), query id (Q), estimated identity (I)
  for (auto &e : results)
  {
    shortResults.emplace_back(MappingResult_CGI{e.refSeqId,
                                                0, // this value will be revised to genome id
                                                e.querySeqId, e.refStartPos, e.queryStartPos,
                                                e.refStartPos / (parameters.minReadLength - 20),
                                                e.nucIdentity});
  }

  /*
   * NOTE: We assume single file contains the sequences for single genome
   * We revise reference sequence id to genome (or file) id
   */
  reviseRefIdToGenomeId(shortResults, refSketch);

  std::vector<MappingResult_CGI> mappings_1way;
  std::vector<MappingResult_CGI> mappings_2way;

  // --- Stage 1: best match per genome/query pair ---
  std::sort(shortResults.begin(), shortResults.end(), cmp_query_bucket);

  for (auto &e : shortResults)
  {
    if (mappings_1way.empty())
      mappings_1way.push_back(e);

    else if (!(e.genomeId == mappings_1way.back().genomeId &&
               e.querySeqId == mappings_1way.back().querySeqId))
    {
      mappings_1way.emplace_back(e);
    }
    else
    {
      mappings_1way.back() = e;
    }
  }

  // std::cerr << "DEBUG: mappings_2way size (initial) = "
  //       << mappings_2way.size() << std::endl;

  /// 2. Now, we compute 2-way ANI
  // For each mapped region, and within a reference bin bucket, single best query mapping is
  // preserved
  {
    std::sort(mappings_1way.begin(), mappings_1way.end(), cmp_refbin_bucket);

    for (auto &e : mappings_1way)
    {
      if (mappings_2way.empty())
        mappings_2way.push_back(e);

      else if (!(e.refSequenceId == mappings_2way.back().refSequenceId &&
                 e.mapRefPosBin == mappings_2way.back().mapRefPosBin))
      {
        mappings_2way.emplace_back(e);
      }
      else
      {
        mappings_2way.back() = e;
      }
    }
  }

  {
    if (parameters.visualize)
    {
      outputVisualizationFile(parameters, mappings_2way, mapper, refSketch, queryFileNo, fileName);
    }
  }

  // Do average for ANI/AAI computation
  // mappings_2way should be sorted by genomeId

  for (auto it = mappings_2way.begin(); it != mappings_2way.end();)
  {
    skch::seqno_t currentGenomeId = it->genomeId;

    // Bucket by genome id
    auto rangeEndIter = std::find_if(it, mappings_2way.end(), [&](const MappingResult_CGI &e)
                                     { return e.genomeId != currentGenomeId; });

    float sumIdentity = 0.0f;
    std::vector<float> fragmentAnis;
    fragmentAnis.reserve(std::distance(it, rangeEndIter));

    skch::seqno_t countGe99 = 0;

    for (auto it2 = it; it2 != rangeEndIter; ++it2)
    {
      sumIdentity += it2->nucIdentity;
      fragmentAnis.push_back(it2->nucIdentity);

      if (it2->nucIdentity >= 99.0f)
        countGe99++;
    }

    // Save the result
    CGI_Results currentResult;

    currentResult.qryGenomeId = queryFileNo;
    currentResult.refGenomeId = currentGenomeId;
    currentResult.countSeq = std::distance(it, rangeEndIter);
    currentResult.totalQueryFragments = totalQueryFragments;
    currentResult.identity = sumIdentity / currentResult.countSeq;

    if (parameters.extendedMetrics)
    {
      std::sort(fragmentAnis.begin(), fragmentAnis.end());

      currentResult.frac99 =
        (currentResult.totalQueryFragments > 0)
          ? static_cast<float>(countGe99) / static_cast<float>(currentResult.totalQueryFragments)
          : 0.0f;

      currentResult.sdAni = computeStdDev(fragmentAnis, currentResult.identity);
      currentResult.q1Ani = percentileFromSorted(fragmentAnis, 0.25);
      currentResult.medianAni = percentileFromSorted(fragmentAnis, 0.50);
      currentResult.q3Ani = percentileFromSorted(fragmentAnis, 0.75);
    }

    CGI_ResultsVector.push_back(currentResult);

    // Advance the iterator
    it = rangeEndIter;
  }
}

/**
 * @brief                             output FastANI results to file
 * @param[in]   parameters            algorithm parameters
 * @param[in]   genomeLengths
 * @param[in]   CGI_ResultsVector     results
 * @param[in]   fileName              file name where results will be reported
 */
void outputCGI(skch::Parameters &parameters,
               std::unordered_map<std::string, uint64_t> &genomeLengths,
               std::vector<cgi::CGI_Results> &CGI_ResultsVector, std::string &fileName)
{
  std::vector<cgi::CGI_Results> outputResults =
    parameters.averageReciprocals ? averageReciprocalResults(parameters, CGI_ResultsVector)
                                  : CGI_ResultsVector;

  // sort result by identity
  std::sort(outputResults.rbegin(), outputResults.rend());

  std::ofstream outFile;
  std::ostream *outstrm = &std::cout;

  if (!fileName.empty())
  {
    outFile.open(fileName);
    outstrm = &outFile;
  }

  if (parameters.header)
  {
    (*outstrm) << "Query"
               << "\t" << "Reference"
               << "\t" << "ANI"
               << "\t" << "MatchedFragments"
               << "\t" << "TotalQueryFragments";

    if (parameters.extendedMetrics)
    {
      (*outstrm) << "\t" << "QueryAlignmentFraction"
                 << "\t" << "ReferenceAlignmentFraction"
                 << "\t" << "FragID_F99"
                 << "\t" << "FragID_Stdev"
                 << "\t" << "FragID_Q1"
                 << "\t" << "FragID_Median"
                 << "\t" << "FragID_Q3";
    }

    (*outstrm) << "\n";
  }

  // Report results
  for (auto &e : outputResults)
  {
    std::string qryGenome = parameters.querySequences[e.qryGenomeId];
    std::string refGenome = parameters.refSequences[e.refGenomeId];

    if (genomeLengths.find(qryGenome) == genomeLengths.end() ||
        genomeLengths.find(refGenome) == genomeLengths.end())
    {
      throw std::runtime_error("ERROR: missing genome length metadata while writing ANI output");
    }

    uint64_t queryGenomeLength = genomeLengths[qryGenome];
    uint64_t refGenomeLength = genomeLengths[refGenome];
    uint64_t minGenomeLength = std::min(queryGenomeLength, refGenomeLength);
    uint64_t sharedLength = e.countSeq * parameters.minReadLength;
    float queryAlignmentCoverage =
      (e.totalQueryFragments > 0)
        ? static_cast<float>(e.countSeq) / static_cast<float>(e.totalQueryFragments)
        : 0.0f;
    float referenceAlignmentCoverage =
      (refGenomeLength > 0) ? static_cast<float>(sharedLength) / static_cast<float>(refGenomeLength)
                            : 0.0f;

    // Checking if shared genome is above a certain fraction of genome length
    if (sharedLength >= minGenomeLength * parameters.minFraction)
    {
      (*outstrm) << qryGenome << "\t" << refGenome << "\t" << e.identity << "\t" << e.countSeq
                 << "\t" << e.totalQueryFragments;

      if (parameters.extendedMetrics)
      {
        (*outstrm) << "\t" << queryAlignmentCoverage << "\t" << referenceAlignmentCoverage << "\t"
                   << e.frac99 << "\t" << e.sdAni << "\t" << e.q1Ani << "\t" << e.medianAni << "\t"
                   << e.q3Ani;
      }

      (*outstrm) << "\n";
    }
  }

  if (outFile.is_open())
    outFile.close();
}

/**
 * @brief                             output FastANI results as lower triangular matrix
 * @param[in]   parameters            algorithm parameters
 * @param[in]   genomeLengths
 * @param[in]   CGI_ResultsVector     results
 * @param[in]   fileName              file name where results will be reported
 */
void outputPhylip(skch::Parameters &parameters,
                  std::unordered_map<std::string, uint64_t> &genomeLengths,
                  std::vector<cgi::CGI_Results> &CGI_ResultsVector, std::string &fileName)
{
  std::unordered_map<std::string, int> genome2Int;     // name of genome -> integer
  std::unordered_map<int, std::string> genome2Int_rev; // integer -> name of genome

  // Assign unique index to the set of query and reference genomes
  for (auto &e : parameters.querySequences)
  {
    auto id = genome2Int.size();
    if (genome2Int.find(e) == genome2Int.end())
    {
      genome2Int[e] = id;
      genome2Int_rev[id] = e;
    }
  }

  for (auto &e : parameters.refSequences)
  {
    auto id = genome2Int.size();
    if (genome2Int.find(e) == genome2Int.end())
    {
      genome2Int[e] = id;
      genome2Int_rev[id] = e;
    }
  }

  int totalGenomes = genome2Int.size();

  // create a square 2-d matrix
  std::vector<std::vector<float>> fastANI_matrix(totalGenomes,
                                                 std::vector<float>(totalGenomes, 0.0));

  // transform FastANI results into 3-tuples
  for (auto &e : CGI_ResultsVector)
  {
    std::string qryGenome = parameters.querySequences[e.qryGenomeId];
    std::string refGenome = parameters.refSequences[e.refGenomeId];

    if (genomeLengths.find(qryGenome) == genomeLengths.end() ||
        genomeLengths.find(refGenome) == genomeLengths.end())
    {
      throw std::runtime_error(
        "ERROR: missing genome length metadata while writing ANI matrix output");
    }

    uint64_t queryGenomeLength = genomeLengths[qryGenome];
    uint64_t refGenomeLength = genomeLengths[refGenome];
    uint64_t minGenomeLength = std::min(queryGenomeLength, refGenomeLength);
    uint64_t sharedLength = e.countSeq * parameters.minReadLength;

    // Checking if shared genome is above a certain fraction of genome length
    if (sharedLength >= minGenomeLength * parameters.minFraction)
    {
      int qGenome = genome2Int[qryGenome];
      int rGenome = genome2Int[refGenome];

      if (qGenome != rGenome) // ignore if both genomes are same
      {
        if (qGenome > rGenome)
        {
          if (fastANI_matrix[qGenome][rGenome] > 0)
            fastANI_matrix[qGenome][rGenome] = (fastANI_matrix[qGenome][rGenome] + e.identity) / 2;
          else
            fastANI_matrix[qGenome][rGenome] = e.identity;
        }
        else
        {
          if (fastANI_matrix[rGenome][qGenome] > 0)
            fastANI_matrix[rGenome][qGenome] = (fastANI_matrix[rGenome][qGenome] + e.identity) / 2;
          else
            fastANI_matrix[rGenome][qGenome] = e.identity;
        }
      }
    }
  }

  std::ofstream outstrm(fileName + ".matrix");

  outstrm << totalGenomes << "\n";

  // Report matrix
  for (int i = 0; i < totalGenomes; i++)
  {
    // output genome name
    outstrm << genome2Int_rev[i];

    for (int j = 0; j < i; j++)
    {
      // output ani values
      // average if computed twice
      std::string val = fastANI_matrix[i][j] > 0.0 ? std::to_string(fastANI_matrix[i][j]) : "NA";
      outstrm << "\t" << val;
    }
    outstrm << "\n";
  }

  outstrm.close();
}

/**
 * @brief                         generate multiple parameter objects from one
 * @details                       purpose it to divide the list of reference genomes
 *                                into as many buckets as requested by splitCount
 * @param[in]   parameters
 * @param[out]  parameters_split
 */
void splitReferenceGenomes(skch::Parameters &parameters,
                           std::vector<skch::Parameters> &parameters_split, int splitCount)
{
  for (int i = 0; i < splitCount; i++)
  {
    parameters_split[i] = parameters;

    // update the reference genomes list
    parameters_split[i].refSequences.clear();

    // assign ref. genome to threads in round-robin fashion
    for (int j = 0; j < parameters.refSequences.size(); j++)
    {
      if (j % splitCount == i)
        parameters_split[i].refSequences.push_back(parameters.refSequences[j]);
    }
  }
}

/**
 * @brief                             update thread local reference genome ids to global ids
 * @param[in/out] CGI_ResultsVector
 */
void correctRefGenomeIds(std::vector<cgi::CGI_Results> &CGI_ResultsVector, int splitIndex,
                         int splitCount)
{
  for (auto &e : CGI_ResultsVector)
    e.refGenomeId = e.refGenomeId * splitCount + splitIndex;
}
} // namespace cgi

#endif
