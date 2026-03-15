#pragma once

#include <fstream>
#include <stdexcept>
#include <string>
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
    out.write((char*)&version, sizeof(version));
    out.write((char*)&parameters.kmerSize, sizeof(parameters.kmerSize));
    out.write((char*)&parameters.windowSize, sizeof(parameters.windowSize));

    size_t n = sketch.minimizerPosLookupIndex.size();
    out.write((char*)&n, sizeof(n));
    out.write((char*)sketch.minimizerPosLookupIndex.data(),
              n * sizeof(sketch.minimizerPosLookupIndex[0]));

    out.close();
  }
}
