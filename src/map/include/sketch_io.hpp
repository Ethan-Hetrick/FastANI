#pragma once

#include <fstream>
#include <stdexcept>
#include <string>
#include <cstdint>

#include "map/include/winSketch.hpp"
#include "map/include/map_parameters.hpp"

namespace skch
{
  inline void saveReferenceSketch(const Sketch& sketch,
                                  const Parameters& parameters,
                                  const std::string& outFile)
  {
    std::ofstream out(outFile, std::ios::binary);
    if(!out)
      throw std::runtime_error("ERROR: cannot open sketch output file");

    uint32_t version = 1;
    out.write(reinterpret_cast<const char*>(&version), sizeof(version));
    out.write(reinterpret_cast<const char*>(&parameters.kmerSize), sizeof(parameters.kmerSize));
    out.write(reinterpret_cast<const char*>(&parameters.windowSize), sizeof(parameters.windowSize));

    // metadata
    size_t nMetadata = sketch.metadata.size();
    out.write(reinterpret_cast<const char*>(&nMetadata), sizeof(nMetadata));
    for(const auto& c : sketch.metadata)
    {
      size_t nameLen = c.name.size();
      out.write(reinterpret_cast<const char*>(&nameLen), sizeof(nameLen));
      out.write(c.name.data(), nameLen);
      out.write(reinterpret_cast<const char*>(&c.len), sizeof(c.len));
    }

    // sequencesByFileInfo
    size_t nSeqByFile = sketch.sequencesByFileInfo.size();
    out.write(reinterpret_cast<const char*>(&nSeqByFile), sizeof(nSeqByFile));
    if(nSeqByFile > 0)
    {
      out.write(reinterpret_cast<const char*>(sketch.sequencesByFileInfo.data()),
                nSeqByFile * sizeof(sketch.sequencesByFileInfo[0]));
    }

    // minimizerIndex
    size_t nMinIdx = sketch.minimizerIndex.size();
    out.write(reinterpret_cast<const char*>(&nMinIdx), sizeof(nMinIdx));
    if(nMinIdx > 0)
    {
      out.write(reinterpret_cast<const char*>(sketch.minimizerIndex.data()),
                nMinIdx * sizeof(sketch.minimizerIndex[0]));
    }

    // minimizerPosLookupIndex
    size_t nKeys = sketch.minimizerPosLookupIndex.size();
    out.write(reinterpret_cast<const char*>(&nKeys), sizeof(nKeys));

    for(const auto& kv : sketch.minimizerPosLookupIndex)
    {
      const MinimizerMapKeyType& key = kv.first;
      const MinimizerMapValueType& vals = kv.second;

      out.write(reinterpret_cast<const char*>(&key), sizeof(key));

      size_t nVals = vals.size();
      out.write(reinterpret_cast<const char*>(&nVals), sizeof(nVals));

      if(nVals > 0)
      {
        out.write(reinterpret_cast<const char*>(vals.data()),
                  nVals * sizeof(vals[0]));
      }
    }

    out.close();
  }

  inline Sketch loadReferenceSketch(const Parameters& parameters,
                                    const std::string& inFile)
  {
    std::ifstream in(inFile, std::ios::binary);
    if(!in)
      throw std::runtime_error("ERROR: cannot open sketch input file");

    Sketch sketch(parameters, true);

    uint32_t version = 0;
    in.read(reinterpret_cast<char*>(&version), sizeof(version));
    if(version != 1)
      throw std::runtime_error("ERROR: unsupported sketch version");

    int savedKmer = 0;
    int savedWindow = 0;
    in.read(reinterpret_cast<char*>(&savedKmer), sizeof(savedKmer));
    in.read(reinterpret_cast<char*>(&savedWindow), sizeof(savedWindow));

    if(savedKmer != parameters.kmerSize)
      throw std::runtime_error("ERROR: sketch kmerSize does not match current run");

    if(savedWindow != parameters.windowSize)
      throw std::runtime_error("ERROR: sketch windowSize does not match current run");

    // metadata
    size_t nMetadata = 0;
    in.read(reinterpret_cast<char*>(&nMetadata), sizeof(nMetadata));
    sketch.metadata.resize(nMetadata);

    for(size_t i = 0; i < nMetadata; i++)
    {
      size_t nameLen = 0;
      in.read(reinterpret_cast<char*>(&nameLen), sizeof(nameLen));

      sketch.metadata[i].name.resize(nameLen);
      in.read(&sketch.metadata[i].name[0], nameLen);

      in.read(reinterpret_cast<char*>(&sketch.metadata[i].len), sizeof(sketch.metadata[i].len));
    }

    // sequencesByFileInfo
    size_t nSeqByFile = 0;
    in.read(reinterpret_cast<char*>(&nSeqByFile), sizeof(nSeqByFile));
    sketch.sequencesByFileInfo.resize(nSeqByFile);
    if(nSeqByFile > 0)
    {
      in.read(reinterpret_cast<char*>(sketch.sequencesByFileInfo.data()),
              nSeqByFile * sizeof(sketch.sequencesByFileInfo[0]));
    }

    // minimizerIndex
    size_t nMinIdx = 0;
    in.read(reinterpret_cast<char*>(&nMinIdx), sizeof(nMinIdx));
    sketch.minimizerIndex.resize(nMinIdx);
    if(nMinIdx > 0)
    {
      in.read(reinterpret_cast<char*>(sketch.minimizerIndex.data()),
              nMinIdx * sizeof(sketch.minimizerIndex[0]));
    }

    // minimizerPosLookupIndex
    size_t nKeys = 0;
    in.read(reinterpret_cast<char*>(&nKeys), sizeof(nKeys));

    for(size_t i = 0; i < nKeys; i++)
    {
      MinimizerMapKeyType key;
      size_t nVals = 0;

      in.read(reinterpret_cast<char*>(&key), sizeof(key));
      in.read(reinterpret_cast<char*>(&nVals), sizeof(nVals));

      auto& vals = sketch.minimizerPosLookupIndex[key];
      vals.resize(nVals);

      if(nVals > 0)
      {
        in.read(reinterpret_cast<char*>(vals.data()),
                nVals * sizeof(vals[0]));
      }
    }

    if(!in)
      throw std::runtime_error("ERROR: failed while reading sketch file");

    sketch.computeFreqHist();
    return sketch;
  }
}