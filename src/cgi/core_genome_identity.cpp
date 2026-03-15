/**
 * @file    core_genome_identity.cpp
 * @ingroup src
 * @author  Chirag Jain <cjain7@gatech.edu>
 */

#include <iostream>
#include <ctime>
#include <chrono>
#include <functional>
#include <omp.h>
#include <memory>

//Own includes
#include "map/include/map_parameters.hpp"
#include "map/include/base_types.hpp"
#include "map/include/parseCmdArgs.hpp"
#include "map/include/winSketch.hpp"
#include "map/include/computeMap.hpp"
#include "map/include/commonFunc.hpp"
#include "cgi/include/computeCoreIdentity.hpp"
#include "map/include/sketch_io.hpp"

int core_genome_identity(int argc, char **argv)
{
  /*
   * Make sure env variable MALLOC_ARENA_MAX is unset
   * for efficient multi-threaded execution
   */
  unsetenv((char *)"MALLOC_ARENA_MAX");
  using namespace std::placeholders;  // for _1, _2, _3...

  //Parse command line arguements
  skch::Parameters parameters;        //sketching and mapping parameters
  skch::parseandSave(argc, argv, parameters);

  std::string fileName = parameters.outFileName;

  //To redirect Mashmap's mapping output to null fs, using file name for CGI output
  parameters.outFileName = "/dev/null";

  //Set up for parallel execution
  omp_set_num_threads(parameters.threads);
  std::vector<skch::Parameters> parameters_split(parameters.threads);
  cgi::splitReferenceGenomes(parameters, parameters_split);

  //Final output vectors of ANI computation (one per thread; merged after parallel region)
  std::vector< std::vector<cgi::CGI_Results> > finalResults_by_thread(parameters.threads);

  std::vector<bool> sanityCheck(parameters.threads, true);
  std::vector<float> ratioDiffs(parameters.threads, true);

#pragma omp parallel for schedule(static,1)
  for (uint64_t i = 0; i < parameters.threads; i++)
  {
    if (omp_get_thread_num() == 0)
      std::cerr << "INFO [thread 0], skch::main, Count of threads executing parallel_for : "
                << omp_get_num_threads() << std::endl;

    //start timer
    auto t0 = skch::Time::now();

    // Build or load the sketch for reference
    std::unique_ptr<skch::Sketch> referSketchPtr;

    if(parameters.loadSketchMode)
    {
      std::string inSketchFile =
        parameters.sketchFile + "." + std::to_string(i);

      referSketchPtr = std::make_unique<skch::Sketch>(
          skch::loadReferenceSketch(parameters_split[i], inSketchFile));

      std::cerr << "INFO [thread " << omp_get_thread_num()
                << "], skch::main, loaded sketch from "
                << inSketchFile << std::endl;
    }
    else
    {
      referSketchPtr = std::make_unique<skch::Sketch>(parameters_split[i]);
    }

    skch::Sketch &referSketch = *referSketchPtr;

    // When loading from sketch, rebuild the per-split reference genome names
    // needed later by outputCGI/outputPhylip.
    if(parameters.loadSketchMode)
    {
      parameters_split[i].refSequences.clear();

      size_t prev = 0;
      for(size_t g = 0; g < referSketch.sequencesByFileInfo.size(); g++)
      {
        size_t end = static_cast<size_t>(referSketch.sequencesByFileInfo[g]);

        std::string genomeName = "sketch_ref_" + std::to_string(g);
        if(prev < referSketch.metadata.size())
          genomeName = referSketch.metadata[prev].name;

        parameters_split[i].refSequences.push_back(genomeName);
        prev = end;
      }
    }

    if(parameters.writeRefSketchMode)
    {
      std::string outSketchFile =
        parameters.writeRefSketchFile + "." + std::to_string(i);

      skch::saveReferenceSketch(referSketch, parameters_split[i], outSketchFile);

      std::cerr << "INFO [thread " << omp_get_thread_num()
                << "], skch::main, wrote sketch to "
                << outSketchFile << std::endl;

      continue;
    }

    std::chrono::duration<double> timeRefSketch = skch::Time::now() - t0;

    if (omp_get_thread_num() == 0)
      std::cerr << "INFO [thread 0], skch::main, Time spent sketching the reference : "
                << timeRefSketch.count() << " sec" << std::endl;

    //Final output vector of ANI computation
    std::vector<cgi::CGI_Results> finalResults_local;

    sanityCheck[i] = referSketch.sanityCheck(parameters.maxRatioDiff);
    ratioDiffs[i] = referSketch.getRatioDifference();

    if(sanityCheck[i])
    {
      //Loop over query genomes
      for(uint64_t queryno = 0; queryno < parameters_split[i].querySequences.size(); queryno++)
      {
        t0 = skch::Time::now();

        skch::MappingResultsVector_t mapResults;
        uint64_t totalQueryFragments = 0;

        auto fn = std::bind(skch::Map::insertL2ResultsToVec, std::ref(mapResults), _1);
        if (omp_get_thread_num() == 0)
          std::cerr << "INFO [thread 0], skch::main, Start Map " << queryno + 1 << std::endl;

        skch::Map mapper = skch::Map(parameters_split[i], referSketch, totalQueryFragments, queryno, fn);

        std::chrono::duration<double> timeMapQuery = skch::Time::now() - t0;

        if (omp_get_thread_num() == 0)
          std::cerr << "INFO [thread 0], skch::main, Time spent mapping fragments in query #"
                    << queryno + 1 << " : " << timeMapQuery.count() << " sec" << std::endl;

        t0 = skch::Time::now();

        cgi::computeCGI(parameters_split[i], mapResults, mapper, referSketch,
                        totalQueryFragments, queryno, fileName, finalResults_local);

        std::chrono::duration<double> timeCGI = skch::Time::now() - t0;

        if (omp_get_thread_num() == 0)
          std::cerr << "INFO [thread 0], skch::main, Time spent post mapping : "
                    << timeCGI.count() << " sec" << std::endl;
      }
    }

    cgi::correctRefGenomeIds(finalResults_local);

    // Store this thread's results without locking; merge after parallel region
    finalResults_by_thread[i] = std::move(finalResults_local);

    std::cerr << "INFO [thread " << omp_get_thread_num()
              << "], skch::main, ready to exit the loop" << std::endl;
  }

  std::cerr << "INFO, skch::main, parallel_for execution finished" << std::endl;

  if(parameters.loadSketchMode)
  {
    parameters.refSequences.clear();
  
    for(uint64_t i = 0; i < parameters.threads; i++)
    {
      for(const auto &name : parameters_split[i].refSequences)
      {
        parameters.refSequences.push_back(name);
      }
    }
  }
  
  if(parameters.writeRefSketchMode)
    return 0;

  // Merge per-thread results (single-threaded, deterministic)
  std::vector<cgi::CGI_Results> finalResults;

  size_t total = 0;
  for(const auto &v : finalResults_by_thread)
    total += v.size();
  finalResults.reserve(total);

  for(auto &v : finalResults_by_thread)
    finalResults.insert(finalResults.end(), v.begin(), v.end());

  for(auto i = 0; i < parameters.threads; i++)
  {
    if(sanityCheck[i] == false)
    {
      std::cerr << "ERROR :: SPLIT " << i << "'s ratio difference "
                << ratioDiffs[i] << " exceeds maximum thresholds." << std::endl;
    }
  }

  std::unordered_map<std::string, uint64_t> genomeLengths;    // name of genome -> length
  cgi::computeGenomeLengths(parameters, genomeLengths);

  //report output in file
  cgi::outputCGI(parameters, genomeLengths, finalResults, fileName);

  //report output as matrix
  if(parameters.matrixOutput)
    cgi::outputPhylip(parameters, genomeLengths, finalResults, fileName);

  if(parameters.visualize && parameters.threads > 1)
  {
    std::string outVisFile = fileName + ".visual";
    std::ofstream ofile(outVisFile);
    for(int i = 0; i < parameters.threads; i++)
    {
      std::string visFileName = fileName + ".visual" + std::to_string(i);
      std::ifstream ifile(visFileName);
      if(!ifile.good())
      {
        ifile.close();
        continue;
      }

      const int BUFFER_SIZE = 4096;
      std::vector<char> buffer(BUFFER_SIZE + 1, 0);
      while(true)
      {
        ifile.read(buffer.data(), BUFFER_SIZE);
        std::streamsize s = ((ifile) ? BUFFER_SIZE : ifile.gcount());
        buffer[s] = 0;
        ofile << buffer.data();
        if(!ifile) break;
      }
      ifile.close();
      unlink(visFileName.c_str());
    }
    ofile.close();
  }

  return 0;
}