/**
 * @file    winSketch.hpp
 * @brief   routines to index the reference
 * @author  Chirag Jain <cjain7@gatech.edu>
 */

#ifndef WIN_SKETCH_HPP
#define WIN_SKETCH_HPP

#include <vector>
#include <algorithm>
#include <unordered_map>
#include <map>
#include <cassert>
#include <zlib.h>
#include <omp.h>

// Own includes
#include "map/include/commonFunc.hpp"
#include "map/include/base_types.hpp"
#include "map/include/map_parameters.hpp"

// External includes
#include "common/murmur3.h"
#include "common/prettyprint.hpp"

namespace skch
{
/**
 * @class     skch::Sketch
 * @brief     sketches and indexes the reference (subject sequence)
 * @details
 *            1.  Minimizers are computed in streaming fashion
 *                Computing minimizers is using double ended queue which gives
 *                O(reference size) complexity
 *                Algorithm described here:
 *                https://people.cs.uct.ac.za/~ksmith/articles/sliding_window_minimum.html
 *
 *            2.  Index hashes into appropriate format to enable fast search at L1 mapping stage
 */
class Sketch
{
  // private members

  // algorithm parameters
  const skch::Parameters &param;

  // Ignore top % most frequent minimizers while lookups
  const float percentageThreshold = 0.0;

  // Minimizers that occur this or more times will be ignored (computed based on
  // percentageThreshold)
  int freqThreshold = std::numeric_limits<int>::max();

  // Make the default constructor private, non-accessible
  Sketch();

public:
  typedef std::vector<MinimizerInfo> MI_Type;
  using MIIter_t = MI_Type::const_iterator;
  using BucketStorage_t = std::vector<MinimizerMetaData>;
  using BucketIter_t = BucketStorage_t::const_iterator;

  // Keep sequence length, name that appear in the sequence (for printing the mappings later)
  std::vector<ContigInfo> metadata;

  /*
   * Keep the information of what sequences come from what file#
   * Example [a, b, c] implies
   *  file 0 contains 0 .. a-1 sequences
   *  file 1 contains a .. b-1
   *  file 2 contains b .. c-1
   */
  std::vector<seqno_t> sequencesByFileInfo;

  // Original reference file paths, one per genome/file in sequencesByFileInfo.
  std::vector<std::string> referenceFiles;
  std::vector<seqno_t> contigToGenomeId;
  std::vector<offset_t> refOffsetAdder;
  std::vector<uint64_t> genomeLengthsByFile;

  // Index for fast seed lookup
  /*
   * [minimizer #1] -> [pos1, pos2, pos3 ...]
   * [minimizer #2] -> [pos1, pos2...]
   * ...
   */
  using MI_Map_t = std::unordered_map<MinimizerMapKeyType, MinimizerMapValueType>;
  MI_Map_t minimizerPosLookupIndex;
  BucketStorage_t minimizerPosLookupData;

private:
  /**
   * Keep list of minimizers, sequence# , their position within seq , here while parsing sequence
   * Note : position is local within each contig
   * Hashes saved here are non-unique, ordered as they appear in the reference
   */
  MI_Type minimizerIndex;

  // Frequency histogram of minimizers
  //[... ,x -> y, ...] implies y number of minimizers occur x times
  std::map<int, int> minimizerFreqHistogram;

  // Sanity check variables
  float hashRatio;
  float uniqHashRatio;
  float ratioDifference;

public:
  /**
   * @brief   constructor
   *          also builds, indexes the minimizer table
   */
  Sketch(const skch::Parameters &p) : param(p)
  {
    auto tBuildStart = skch::Time::now();
    this->build();
    auto tAfterBuild = skch::Time::now();
    this->index();
    auto tAfterIndex = skch::Time::now();
    this->computeFreqHist();
    auto tAfterFreqHist = skch::Time::now();

    if (omp_get_thread_num() == 0)
    {
      std::chrono::duration<double> buildTime = tAfterBuild - tBuildStart;
      std::chrono::duration<double> indexTime = tAfterIndex - tAfterBuild;
      std::chrono::duration<double> freqHistTime = tAfterFreqHist - tAfterIndex;

      std::cerr << "INFO [thread 0], skch::Sketch, Time spent collecting minimizers : "
                << buildTime.count() << " sec" << std::endl;
      std::cerr << "INFO [thread 0], skch::Sketch, Time spent building lookup index : "
                << indexTime.count() << " sec" << std::endl;
      std::cerr << "INFO [thread 0], skch::Sketch, Time spent computing frequency histogram : "
                << freqHistTime.count() << " sec" << std::endl;
    }
  }

  Sketch(const skch::Parameters &p, bool deferBuild) : param(p)
  {
    if (!deferBuild)
    {
      auto tBuildStart = skch::Time::now();
      this->build();
      auto tAfterBuild = skch::Time::now();
      this->index();
      auto tAfterIndex = skch::Time::now();
      this->computeFreqHist();
      auto tAfterFreqHist = skch::Time::now();

      if (omp_get_thread_num() == 0)
      {
        std::chrono::duration<double> buildTime = tAfterBuild - tBuildStart;
        std::chrono::duration<double> indexTime = tAfterIndex - tAfterBuild;
        std::chrono::duration<double> freqHistTime = tAfterFreqHist - tAfterIndex;

        std::cerr << "INFO [thread 0], skch::Sketch, Time spent collecting minimizers : "
                  << buildTime.count() << " sec" << std::endl;
        std::cerr << "INFO [thread 0], skch::Sketch, Time spent building lookup index : "
                  << indexTime.count() << " sec" << std::endl;
        std::cerr << "INFO [thread 0], skch::Sketch, Time spent computing frequency histogram : "
                  << freqHistTime.count() << " sec" << std::endl;
      }
    }
  }

private:
  /**
   * @brief     build the sketch table
   * @details   compute and save minimizers from the reference sequence(s)
   *            assuming a fixed window size
   */

  void build()
  {
    this->referenceFiles = param.refSequences;

    // sequence counter while parsing file
    seqno_t seqCounter = 0;

    // Reserve once for the full reference set to reduce geometric growth of
    // the global minimizer vector without forcing the per-contig reallocations
    // that previously regressed build time.
    const int safeWindow = std::max(1, param.windowSize);
    const size_t estMinimizers =
      static_cast<size_t>(std::max<uint64_t>(500000, param.referenceSize / safeWindow));
    this->minimizerIndex.reserve(estMinimizers);

    if (omp_get_thread_num() == 0)
      std::cerr << "INFO [thread 0], skch::Sketch::build, window size for minimizer sampling  = "
                << param.windowSize << std::endl;

    for (const auto &fileName : param.refSequences)
    {

#ifdef DEBUG
      std::cerr << "INFO, skch::Sketch::build, building minimizer index for " << fileName
                << std::endl;
#endif

      // Open the file using kseq
      gzFile fp = gzopen(fileName.c_str(), "r");
      gzbuffer(fp, 1 << 20);
      kseq_t *seq = kseq_init(fp);

      // size of sequence
      offset_t len;

      while ((len = kseq_read(seq)) >= 0)
      {
        // Save the sequence name
        metadata.push_back(ContigInfo{seq->name.s, (offset_t)seq->seq.l});

        // Is the sequence too short?
        if (len < param.windowSize || len < param.kmerSize)
        {
#ifdef DEBUG
          std::cerr << "WARNING, skch::Sketch::build, found an unusually short sequence relative "
                       "to kmer and window size"
                    << std::endl;
#endif
        }
        else
        {
          skch::CommonFunc::addMinimizers(this->minimizerIndex, seq, param.kmerSize,
                                          param.windowSize, param.alphabetSize, seqCounter);
        }

        seqCounter++;
      }

      sequencesByFileInfo.push_back(seqCounter);

      kseq_destroy(seq);
      gzclose(fp); // close the file handler
    }

    if (omp_get_thread_num() == 0)
      std::cerr << "INFO [thread 0], skch::Sketch::build, minimizers picked from reference = "
                << minimizerIndex.size() << std::endl;

    this->buildDerivedMetadata();
  }

  void buildDerivedMetadata()
  {
    contigToGenomeId.assign(metadata.size(), -1);
    refOffsetAdder.resize(metadata.size());
    genomeLengthsByFile.assign(sequencesByFileInfo.size(), 0);

    size_t start = 0;
    offset_t runningOffset = 0;
    for (size_t genomeId = 0; genomeId < sequencesByFileInfo.size(); genomeId++)
    {
      const size_t end = static_cast<size_t>(sequencesByFileInfo[genomeId]);
      uint64_t genomeLen = 0;

      for (size_t contigId = start; contigId < end && contigId < metadata.size(); contigId++)
      {
        contigToGenomeId[contigId] = static_cast<seqno_t>(genomeId);
        refOffsetAdder[contigId] = runningOffset;
        runningOffset += metadata[contigId].len;

        const uint64_t contigLen = static_cast<uint64_t>(metadata[contigId].len);
        const uint64_t usableLen = (contigLen / static_cast<uint64_t>(param.minReadLength)) *
                                   static_cast<uint64_t>(param.minReadLength);
        genomeLen += usableLen;
      }

      genomeLengthsByFile[genomeId] = genomeLen;
      start = end;
    }
  }

  /**
   * @brief   build the index for fast lookups using minimizer table
   */
  void index()
  {
    std::unordered_map<MinimizerMapKeyType, uint32_t> bucketCounts;
    bucketCounts.reserve(minimizerIndex.size() / 4);

    // First pass: count payload sizes for each minimizer hash.
    for (auto &e : minimizerIndex)
      bucketCounts[e.hash] += 1;

    minimizerPosLookupIndex.clear();
    minimizerPosLookupIndex.reserve(bucketCounts.size());

    minimizerPosLookupData.clear();
    minimizerPosLookupData.resize(minimizerIndex.size());

    std::unordered_map<MinimizerMapKeyType, uint32_t> writeOffsets;
    writeOffsets.reserve(bucketCounts.size());

    uint32_t nextOffset = 0;
    for (const auto &bucket : bucketCounts)
    {
      minimizerPosLookupIndex.emplace(bucket.first, MinimizerBucketSpan{nextOffset, bucket.second});
      writeOffsets.emplace(bucket.first, nextOffset);
      nextOffset += bucket.second;
    }

    // Second pass: write each payload element into the flat contiguous buffer.
    for (const auto &e : minimizerIndex)
    {
      uint32_t &writeOffset = writeOffsets[e.hash];
      minimizerPosLookupData[writeOffset++] = MinimizerMetaData{e.seqId, e.wpos};
    }

    if (omp_get_thread_num() == 0)
      std::cerr << "INFO [thread 0], skch::Sketch::index, unique minimizers = "
                << minimizerPosLookupIndex.size() << std::endl;
  }

  /**
   * @brief   report the frequency histogram of minimizers using position lookup index
   *          and compute which high frequency minimizers to ignore
   */
  void computeFreqHist()
  {
    if (this->percentageThreshold <= 0.0f)
    {
      this->minimizerFreqHistogram.clear();
      this->freqThreshold = std::numeric_limits<int>::max();

      if (omp_get_thread_num() == 0)
        std::cerr << "INFO [thread 0], skch::Sketch::computeFreqHist, consider all minimizers "
                     "during lookup."
                  << std::endl;

      return;
    }

    // 1. Compute histogram

    for (auto &e : this->minimizerPosLookupIndex)
      this->minimizerFreqHistogram[e.second.size()] += 1;

    if (omp_get_thread_num() == 0)
      std::cerr
        << "INFO [thread 0], skch::Sketch::computeFreqHist, Frequency histogram of minimizers = "
        << *this->minimizerFreqHistogram.begin() << " ... "
        << *this->minimizerFreqHistogram.rbegin() << std::endl;

    // 2. Compute frequency threshold to ignore most frequent minimizers

    int64_t totalUniqueMinimizers = this->minimizerPosLookupIndex.size();
    int64_t minimizerToIgnore = totalUniqueMinimizers * percentageThreshold / 100;

    int64_t sum = 0;

    // Iterate from highest frequent minimizers
    for (auto it = this->minimizerFreqHistogram.rbegin(); it != this->minimizerFreqHistogram.rend();
         it++)
    {
      sum += it->second; // add frequency
      if (sum < minimizerToIgnore)
      {
        this->freqThreshold = it->first;
        // continue
      }
      else if (sum == minimizerToIgnore)
      {
        this->freqThreshold = it->first;
        break;
      }
      else
      {
        break;
      }
    }

    if (this->freqThreshold != std::numeric_limits<int>::max())
    {
      if (omp_get_thread_num() == 0)
        std::cerr << "INFO [thread 0], skch::Sketch::computeFreqHist, With threshold "
                  << this->percentageThreshold
                  << "%, ignore minimizers occurring >= " << this->freqThreshold
                  << " times during lookup." << std::endl;
    }
    else
    {
      if (omp_get_thread_num() == 0)
        std::cerr << "INFO [thread 0], skch::Sketch::computeFreqHist, consider all minimizers "
                     "during lookup."
                  << std::endl;
    }
  }

public:
  /**
   * @brief               search hash associated with given position inside the index
   * @details             if MIIter_t iter is returned, than *iter's wpos >= winpos
   * @param[in]   seqId
   * @param[in]   winpos
   * @return              iterator to the minimizer in the index
   */
  MIIter_t searchIndex(seqno_t seqId, offset_t winpos) const
  {
    std::pair<seqno_t, offset_t> searchPosInfo(seqId, winpos);

    /*
     * std::lower_bound --  Returns an iterator pointing to the first element in the range
     *                      that is not less than (i.e. greater or equal to) value.
     */
    MIIter_t iter = std::lower_bound(this->minimizerIndex.begin(), this->minimizerIndex.end(),
                                     searchPosInfo, cmp);

    return iter;
  }

  /**
   * @brief     Return end iterator on minimizerIndex
   */
  MIIter_t getMinimizerIndexEnd() const
  {
    return this->minimizerIndex.end();
  }

  friend void saveReferenceSketch(const Sketch &sketch, const Parameters &parameters,
                                  const std::string &outFile);

  friend Sketch loadReferenceSketch(const Parameters &parameters, const std::string &inFile);

  int getFreqThreshold() const
  {
    return this->freqThreshold;
  }

  BucketIter_t bucketBegin(const MinimizerMapValueType &span) const
  {
    return this->minimizerPosLookupData.begin() + span.offset;
  }

  BucketIter_t bucketEnd(const MinimizerMapValueType &span) const
  {
    return this->minimizerPosLookupData.begin() + span.offset + span.count;
  }

  float getRatioDifference() const
  {
    return this->ratioDifference;
  }

  float getUniqRation() const
  {
    return this->uniqHashRatio;
  }

  float getHashRatio() const
  {
    return this->hashRatio;
  }

  bool sanityCheck(float maxRatioDiff)
  {
    if (!param.sanityCheck) // Return true if no sanity check is requested
      return true;
    std::size_t totalSize = 0, totalLength = 0;
    for (auto &rx : minimizerPosLookupIndex)
    {
      totalSize += rx.second.size();
    }
    for (auto &cx : metadata)
    {
      totalLength += cx.len;
    }
    this->hashRatio = float(totalLength) / float(totalSize);
    this->uniqHashRatio = float(totalLength) / float(minimizerPosLookupIndex.size());
    // std::cout << "Ratio of Total Ref. Length/Total Occ. Hashes " << hashRatio << std::endl;
    // std::cout << "Ratio of Total Ref. Length/Total No. Hashes " << uniqHashRatio << std::endl;
    this->ratioDifference = std::abs(hashRatio - uniqHashRatio);
    if (this->ratioDifference > maxRatioDiff)
    {
      // std::cerr << "ERROR : Ratio difference is large, Possible Repeats!" << std::endl;
      return false;
    }
    return true;
  }

private:
  /**
   * @brief     functor for comparing minimizers by their position in minimizerIndex
   * @details   used for locating minimizers with the required positional information
   */
  struct compareMinimizersByPos
  {
    typedef std::pair<seqno_t, offset_t> P;

    bool operator()(const MinimizerInfo &m, const P &val)
    {
      return (P(m.seqId, m.wpos) < val);
    }

    bool operator()(const P &val, const MinimizerInfo &m)
    {
      return (val < P(m.seqId, m.wpos));
    }
  } cmp;

}; // End of class Sketch
} // End of namespace skch

#endif
