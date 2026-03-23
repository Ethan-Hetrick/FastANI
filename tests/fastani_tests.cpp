
#include <algorithm>
#include <functional>
#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <sstream>
#include <cctype>
#include <cstdio>

#include <catch2/catch_test_macros.hpp>

int core_genome_identity(int argc, char **argv);

struct CGIEntry
{
  std::string leftx, rightx;
  float identity;
  int countSeq, totalQueryFragments;
};

std::vector<std::string> get_file_contents(const std::string &fname)
{
  std::vector<std::string> file_contents;
  std::ifstream ifile(fname);
  std::string str;
  while (std::getline(ifile, str))
  {
    file_contents.push_back(str);
  }
  std::sort(file_contents.begin(), file_contents.end());
  return file_contents;
}

std::vector<CGIEntry> read_fastani_output(const std::string &fname)
{
  std::vector<CGIEntry> fastani_entries;
  auto file_contents = get_file_contents(fname);
  for (auto &str : file_contents)
  {
    CGIEntry cgx;
    std::stringstream stx(str);
    stx >> cgx.leftx;
    stx >> cgx.rightx;
    stx >> cgx.identity;
    stx >> cgx.countSeq;
    stx >> cgx.totalQueryFragments;
    fastani_entries.push_back(cgx);
  }
  return fastani_entries;
}

void write_lines(const std::string &fname, const std::vector<std::string> &lines)
{
  std::ofstream ofile(fname);
  for (const auto &line : lines)
  {
    ofile << line << "\n";
  }
}

void write_mixed_case_genome(const std::string &input, const std::string &output,
                             std::size_t lowercase_after_base)
{
  std::ifstream ifile(input);
  std::ofstream ofile(output);
  std::string line;
  std::size_t seen_bases = 0;

  while (std::getline(ifile, line))
  {
    if (!line.empty() && line[0] == '>')
    {
      ofile << line << "\n";
      continue;
    }

    for (char &c : line)
    {
      if (std::isalpha(static_cast<unsigned char>(c)))
      {
        if (seen_bases >= lowercase_after_base)
        {
          c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        }
        seen_bases++;
      }
    }

    ofile << line << "\n";
  }
}

TEST_CASE("Single Threaded Pair Query Ref", "[single threaded pair]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"single-pair",
                        "-q",
                        "data/Escherichia_coli_str_K12_MG1655.fna",
                        "-r",
                        "data/Shigella_flexneri_2a_01.fna",
                        "-o",
                        "stsrsq-test.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));

  auto finalResults = read_fastani_output("stsrsq-test.txt");
  REQUIRE(finalResults.size() == 1);
  REQUIRE(finalResults[0].identity > 97.663);
  REQUIRE(finalResults[0].identity < 97.665);
  REQUIRE(finalResults[0].countSeq == 1322);
  REQUIRE(finalResults[0].totalQueryFragments == 1547);
  auto fx = get_file_contents("stsrsq-test.txt");
  auto ref_fx = get_file_contents("data/stsrsq-test.txt");
  REQUIRE(fx == ref_fx);
  fx = get_file_contents("stsrsq-test.txt.visual");
  ref_fx = get_file_contents("data/stsrsq-test.txt.visual");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Single Threaded Pair Query Ref Mid-Range ANI", "[single threaded pair][mid-range ani]")
{
  const char *argv[] = {"single-pair-mid-range",
                        "-q",
                        "data/Shigella_flexneri_2a_01.fna",
                        "-r",
                        "data/Escherichia_albertii_CP024282.fna",
                        "-o",
                        "midrange-pair-test.txt"};
  core_genome_identity(7, const_cast<char **>(argv));

  auto finalResults = read_fastani_output("midrange-pair-test.txt");
  REQUIRE(finalResults.size() == 1);
  REQUIRE(finalResults[0].identity > 89.8640);
  REQUIRE(finalResults[0].identity < 89.8642);
  REQUIRE(finalResults[0].countSeq == 1180);
  REQUIRE(finalResults[0].totalQueryFragments == 1608);

  auto fx = get_file_contents("midrange-pair-test.txt");
  auto ref_fx = get_file_contents("data/shigella_vs_escherichia_albertii_cp024282.txt");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Single Threaded Multi Query", "[single threaded multi query]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"single-ref-multi-query",
                        "--ql",
                        "data/D4/multiq.txt",
                        "-r",
                        "data/D4/2000031001.LargeContigs.fna",
                        "-o",
                        "stsrmq-test.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));

  //
  auto finalResults = read_fastani_output("stsrmq-test.txt");
  REQUIRE(finalResults.size() == 2);
  // data/2000031004.LargeContigs.fna
  // data/2000031001.LargeContigs.fna        99.9493 1708    1722
  REQUIRE(finalResults[0].identity > 99.9492);
  REQUIRE(finalResults[0].identity < 99.9494);
  REQUIRE(finalResults[0].countSeq == 1708);
  REQUIRE(finalResults[0].totalQueryFragments == 1722);
  // data/2000031006.LargeContigs.fna
  // data/2000031001.LargeContigs.fna        99.9973 1259    3517
  REQUIRE(finalResults[1].identity > 99.9867);
  REQUIRE(finalResults[1].identity < 99.9969);
  REQUIRE(finalResults[1].countSeq == 1700);
  REQUIRE(finalResults[1].totalQueryFragments == 1795);
  auto fx = get_file_contents("stsrmq-test.txt");
  auto ref_fx = get_file_contents("data/stsrmq-test.txt");
  REQUIRE(fx == ref_fx);
  fx = get_file_contents("stsrmq-test.txt.visual");
  ref_fx = get_file_contents("data/stsrmq-test.txt.visual");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Single Threaded Multi Ref.", "[single threaded multi ref.]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"single-thread-multi-ref-single-query",
                        "-q",
                        "data/D4/2000031001.LargeContigs.fna",
                        "--rl",
                        "data/D4/multiref.txt",
                        "-o",
                        "stmrsq-test.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("stmrsq-test.txt");
  REQUIRE(finalResults.size() == 2);
  // data/D4/2000031001.LargeContigs.fna
  // data/D4/2000031004.LargeContigs.fna     99.9759 1704    1711
  REQUIRE(finalResults[0].identity > 99.9758);
  REQUIRE(finalResults[0].identity < 99.9760);
  REQUIRE(finalResults[0].countSeq == 1704);
  REQUIRE(finalResults[0].totalQueryFragments == 1711);
  // data/D4/2000031001.LargeContigs.fna
  // data/D4/2000031006.LargeContigs.fna     99.9867 1703    1711
  REQUIRE(finalResults[1].identity > 99.9866);
  REQUIRE(finalResults[1].identity < 99.9868);
  REQUIRE(finalResults[1].countSeq == 1703);
  REQUIRE(finalResults[1].totalQueryFragments == 1711);
  auto fx = get_file_contents("stmrsq-test.txt");
  auto ref_fx = get_file_contents("data/stmrsq-test.txt");
  REQUIRE(fx == ref_fx);
  fx = get_file_contents("stmrsq-test.txt.visual");
  ref_fx = get_file_contents("data/stmrsq-test.txt.visual");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Single Threaded Multi Q. Multi Ref.", "[single threaded multi q. multi ref.]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"multiq-multi-ref",      "--ql",    "data/D4/multiq2.txt", "--rl",
                        "data/D4/multiref2.txt", "-o",      "stmqmr-test.txt",     "-s",
                        "--visualize",           "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("stmqmr-test.txt");
  REQUIRE(finalResults.size() == 6);
  // data/D4/2000031001.LargeContigs.fna
  // data/D4/2000031008.LargeContigs.fna     99.9785 1700    1711
  REQUIRE(finalResults[0].identity < 99.9786);
  REQUIRE(finalResults[0].identity > 99.9784);
  REQUIRE(finalResults[0].countSeq == 1700);
  REQUIRE(finalResults[0].totalQueryFragments == 1711);
  // data/D4/2000031001.LargeContigs.fna
  // data/D4/2000031009.LargeContigs.fna     99.9795 1704    1711
  REQUIRE(finalResults[1].identity > 99.9794);
  REQUIRE(finalResults[1].identity < 99.9796);
  REQUIRE(finalResults[1].countSeq == 1704);
  REQUIRE(finalResults[1].totalQueryFragments == 1711);
  // data/D4/2000031004.LargeContigs.fna
  // data/D4/2000031008.LargeContigs.fna     99.9599 1699    1722
  REQUIRE(finalResults[2].identity > 99.9598);
  REQUIRE(finalResults[2].identity < 99.9600);
  REQUIRE(finalResults[2].countSeq == 1699);
  REQUIRE(finalResults[2].totalQueryFragments == 1722);
  // data/D4/2000031004.LargeContigs.fna
  // data/D4/2000031009.LargeContigs.fna     99.9564 1706    1722
  REQUIRE(finalResults[3].identity > 99.9563);
  REQUIRE(finalResults[3].identity < 99.9565);
  REQUIRE(finalResults[3].countSeq == 1706);
  REQUIRE(finalResults[3].totalQueryFragments == 1722);
  // data/D4/2000031006.LargeContigs.fna
  // data/D4/2000031008.LargeContigs.fna     99.9769 1784    1795
  REQUIRE(finalResults[4].identity > 99.9768);
  REQUIRE(finalResults[4].identity < 99.9770);
  REQUIRE(finalResults[4].countSeq == 1784);
  REQUIRE(finalResults[4].totalQueryFragments == 1795);
  // data/D4/2000031006.LargeContigs.fna
  // data/D4/2000031009.LargeContigs.fna     99.9763 1727    1795
  REQUIRE(finalResults[5].identity > 99.9762);
  REQUIRE(finalResults[5].identity < 99.9764);
  REQUIRE(finalResults[5].countSeq == 1727);
  REQUIRE(finalResults[5].totalQueryFragments == 1795);
  auto fx = get_file_contents("stmqmr-test.txt");
  auto ref_fx = get_file_contents("data/stmqmr-test.txt");
  REQUIRE(fx == ref_fx);
  fx = get_file_contents("stmqmr-test.txt.visual");
  ref_fx = get_file_contents("data/stmqmr-test.txt.visual");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Multi Threaded Multi Q. Multi Ref.", "[multi threaded multi q. multi ref.]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"multiq-multi-ref",
                        "--ql",
                        "data/D4/multiq2.txt",
                        "--rl",
                        "data/D4/multiref2.txt",
                        "-t",
                        "2",
                        "-o",
                        "mtmqmr-test.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(12, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("mtmqmr-test.txt");
  REQUIRE(finalResults.size() == 6);
  // data/D4/2000031001.LargeContigs.fna
  // data/D4/2000031008.LargeContigs.fna     99.9785 1700    1711
  REQUIRE(finalResults[0].identity > 99.9784);
  REQUIRE(finalResults[0].identity < 99.9786);
  REQUIRE(finalResults[0].countSeq == 1700);
  REQUIRE(finalResults[0].totalQueryFragments == 1711);
  // data/D4/2000031001.LargeContigs.fna
  // data/D4/2000031009.LargeContigs.fna     99.9795 1704    1711
  REQUIRE(finalResults[1].identity > 99.9794);
  REQUIRE(finalResults[1].identity < 99.9796);
  REQUIRE(finalResults[1].countSeq == 1704);
  REQUIRE(finalResults[1].totalQueryFragments == 1711);
  // data/D4/2000031004.LargeContigs.fna
  // data/D4/2000031008.LargeContigs.fna     99.9599 1699    1722
  REQUIRE(finalResults[2].identity > 99.9598);
  REQUIRE(finalResults[2].identity < 99.9600);
  REQUIRE(finalResults[2].countSeq == 1699);
  REQUIRE(finalResults[2].totalQueryFragments == 1722);
  // data/D4/2000031004.LargeContigs.fna
  // data/D4/2000031009.LargeContigs.fna     99.9564 1706    1722
  REQUIRE(finalResults[3].identity > 99.9563);
  REQUIRE(finalResults[3].identity < 99.9565);
  REQUIRE(finalResults[3].countSeq == 1706);
  REQUIRE(finalResults[3].totalQueryFragments == 1722);
  // data/D4/2000031006.LargeContigs.fna
  // data/D4/2000031008.LargeContigs.fna     99.9769 1784    1795
  REQUIRE(finalResults[4].identity > 99.9768);
  REQUIRE(finalResults[4].identity < 99.9770);
  REQUIRE(finalResults[4].countSeq == 1784);
  REQUIRE(finalResults[4].totalQueryFragments == 1795);
  // data/D4/2000031006.LargeContigs.fna
  // data/D4/2000031009.LargeContigs.fna     99.9763 1727    1795
  REQUIRE(finalResults[5].identity > 99.9762);
  REQUIRE(finalResults[5].identity < 99.9764);
  REQUIRE(finalResults[5].countSeq == 1727);
  REQUIRE(finalResults[5].totalQueryFragments == 1795);
  auto fx = get_file_contents("mtmqmr-test.txt");
  auto ref_fx = get_file_contents("data/mtmqmr-test.txt");
  REQUIRE(fx == ref_fx);
  fx = get_file_contents("mtmqmr-test.txt.visual");
  ref_fx = get_file_contents("data/mtmqmr-test.txt.visual");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Single Threaded Multi Q. Multi Ref. Repeats",
          "[single threaded multi q. multi ref. rpeats]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"multiq-multi-ref",
                        "--ql",
                        "data/D4/multiq2.txt",
                        "--rl",
                        "data/multiref3.txt",
                        "-t",
                        "1",
                        "-o",
                        "stmqmr-rpt-test.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(12, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("stmqmr-rpt-test.txt");
  REQUIRE(finalResults.size() == 6);
  auto fx = get_file_contents("stmqmr-rpt-test.txt");
  auto ref_fx = get_file_contents("data/stmqmr-rpt-test.txt");
  REQUIRE(fx == ref_fx);
  fx = get_file_contents("stmqmr-rpt-test.txt.visual");
  ref_fx = get_file_contents("data/stmqmr-rpt-test.txt.visual");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Multi Threaded Multi Q. Multi Ref. Repeats",
          "[multi threaded multi q. multi ref. rpeats]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"multiq-multi-ref",
                        "--ql",
                        "data/D4/multiq2.txt",
                        "--rl",
                        "data/multiref3.txt",
                        "-t",
                        "2",
                        "-o",
                        "mtmqmr-rpt-test.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(12, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("mtmqmr-rpt-test.txt");
  REQUIRE(finalResults.size() == 6);
  auto fx = get_file_contents("mtmqmr-rpt-test.txt");
  auto ref_fx = get_file_contents("data/mtmqmr-rpt-test.txt");
  REQUIRE(fx == ref_fx);
  fx = get_file_contents("mtmqmr-rpt-test.txt.visual");
  ref_fx = get_file_contents("data/mtmqmr-rpt-test.txt.visual");
  REQUIRE(fx == ref_fx);
}

TEST_CASE("Repeat A2048 and 8AT", "[repeat interval 1]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-8AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_8ats_2048.fa",
                        "-o",
                        "repeat-A2048-8AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-8AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Repeat A2048 and 12AT", "[repeat interval 2]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-12AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_12ats_2048.fa",
                        "-o",
                        "repeat-A2048-12AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-12AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Repeat A2048 and 16AT", "[repeat interval 3]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-16AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_16ats_2048.fa",
                        "-o",
                        "repeat-A2048-16AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-16AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Repeat A2048 and 20AT", "[repeat interval 4]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-20AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_20ats_2048.fa",
                        "-o",
                        "repeat-A2048-20AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-20AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Repeat A2048 and 24AT", "[repeat interval 5]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-24AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_24ats_2048.fa",
                        "-o",
                        "repeat-A2048-24AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-24AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Repeat A2048 and 32AT", "[repeat interval 6]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-32AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_32ats_2048.fa",
                        "-o",
                        "repeat-A2048-32AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-32AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Repeat A2048 and 64AT", "[repeat interval 7]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-64AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_64ats_2048.fa",
                        "-o",
                        "repeat-A2048-64AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-64AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Repeat A2048 and 128AT", "[repeat interval 7]")
{
  // -q [QUERY_GENOME] -r [REFERENCE_GENOME] -o [OUTPUT_FILE]
  const char *argv[] = {"repeat-A2048-128AT",
                        "-q",
                        "data/repeat_as_2048.fa",
                        "-r",
                        "data/repeat_128ats_2048.fa",
                        "-o",
                        "repeat-A2048-128AT.txt",
                        "-s",
                        "--visualize",
                        "--matrix"};
  //
  core_genome_identity(10, const_cast<char **>(argv));
  //
  auto finalResults = read_fastani_output("repeat-A2048-128AT.txt");
  REQUIRE(finalResults.size() == 0);
}

TEST_CASE("Mixed-case query matches uppercase query", "[mixed case query]")
{
  const std::string mixedQuery = "mixed-query-after-4096.fna";
  write_mixed_case_genome("data/Escherichia_coli_str_K12_MG1655.fna", mixedQuery, 4096);

  const char *baselineArgv[] = {"mixed-case-baseline",
                                "-q",
                                "data/Escherichia_coli_str_K12_MG1655.fna",
                                "-r",
                                "data/Shigella_flexneri_2a_01.fna",
                                "-o",
                                "mixed-case-baseline.txt"};
  core_genome_identity(7, const_cast<char **>(baselineArgv));

  const char *mixedArgv[] = {"mixed-case-query",
                             "-q",
                             "mixed-query-after-4096.fna",
                             "-r",
                             "data/Shigella_flexneri_2a_01.fna",
                             "-o",
                             "mixed-case-query.txt"};
  core_genome_identity(7, const_cast<char **>(mixedArgv));

  auto baseline = read_fastani_output("mixed-case-baseline.txt");
  auto mixed = read_fastani_output("mixed-case-query.txt");

  REQUIRE(baseline.size() == 1);
  REQUIRE(mixed.size() == 1);
  REQUIRE(baseline[0].rightx == mixed[0].rightx);
  REQUIRE(baseline[0].identity == mixed[0].identity);
  REQUIRE(baseline[0].countSeq == mixed[0].countSeq);
  REQUIRE(baseline[0].totalQueryFragments == mixed[0].totalQueryFragments);
}

TEST_CASE("Batched sketch loading matches non-batched output", "[batched sketch parity]")
{
  const std::string refList = "batched-sketch-ref-list.txt";
  write_lines(refList, {
                         "data/D4/2000031001.LargeContigs.fna",
                         "data/D4/2000031004.LargeContigs.fna",
                         "data/D4/2000031008.LargeContigs.fna",
                         "data/D4/2000031009.LargeContigs.fna",
                       });

  const char *writeSketchArgv[] = {"write-batched-sketch",
                                   "--rl",
                                   "batched-sketch-ref-list.txt",
                                   "--write-ref-sketch",
                                   "batched-sketch-db",
                                   "-t",
                                   "2"};
  core_genome_identity(7, const_cast<char **>(writeSketchArgv));

  const char *noSketchArgv[] = {"batched-sketch-nosketch",
                                "-q",
                                "data/D4/2000031001.LargeContigs.fna",
                                "--rl",
                                "batched-sketch-ref-list.txt",
                                "-t",
                                "2",
                                "-o",
                                "batched-sketch-nosketch.txt"};
  core_genome_identity(9, const_cast<char **>(noSketchArgv));

  const char *sketchAllArgv[] = {"batched-sketch-all",
                                 "-q",
                                 "data/D4/2000031001.LargeContigs.fna",
                                 "--sketch",
                                 "batched-sketch-db",
                                 "-t",
                                 "2",
                                 "-o",
                                 "batched-sketch-all.txt"};
  core_genome_identity(9, const_cast<char **>(sketchAllArgv));

  const char *sketchBatchArgv[] = {"batched-sketch-batch1",
                                   "-q",
                                   "data/D4/2000031001.LargeContigs.fna",
                                   "--sketch",
                                   "batched-sketch-db",
                                   "--batch-size",
                                   "1",
                                   "-t",
                                   "2",
                                   "-o",
                                   "batched-sketch-batch1.txt"};
  core_genome_identity(11, const_cast<char **>(sketchBatchArgv));

  auto noSketch = get_file_contents("batched-sketch-nosketch.txt");
  auto sketchAll = get_file_contents("batched-sketch-all.txt");
  auto sketchBatch = get_file_contents("batched-sketch-batch1.txt");

  REQUIRE(noSketch.size() == 4);
  REQUIRE(noSketch == sketchAll);
  REQUIRE(noSketch == sketchBatch);
}
