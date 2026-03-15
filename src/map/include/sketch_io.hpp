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

    // number of minimizer keys in the lookup index
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
                  nVals * sizeof(MinimizerMetaData));
      }
    }

    out.close();
  }
}