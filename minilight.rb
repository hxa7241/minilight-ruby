#!/usr/bin/env ruby
#------------------------------------------------------------------------------#
#                                                                              #
#  MiniLight Ruby : minimal global illumination renderer                       #
#  Harrison Ainsworth / HXA7241 : 2006-2008, 2013.                             #
#                                                                              #
#  http://www.hxa.name/minilight                                               #
#                                                                              #
#------------------------------------------------------------------------------#


# add the directory containing this file to the require/load search list
BEGIN { $:.push( File.dirname( $0 ) ) }


require 'Random'
require 'Image'
require 'Scene'
require 'Camera'




# Control module and entry point.
#
# Handles command-line UI, and runs the main progressive-refinement render
# loop.
#
# Supply a model file pathname as the command-line argument. Or -? for help.




#-- user messages --------------------------------------------------------------

TITLE  = "MiniLight 1.6 Ruby"
AUTHOR = "Harrison Ainsworth / HXA7241 : 2006-2008, 2013."
URL    = "http://www.hxa.name/minilight"

BANNER = "\n  " + TITLE + " - " + URL + "\n\n"

HELP   = "\n#{("-" * 70)}\n  #{TITLE}\n\n  #{AUTHOR}\n  #{URL}\n\n" +
   "  2013-05-04\n" + "#{("-" * 70)}\n\n" +
   "MiniLight is a minimal global illumination renderer.\n" +
   "\n" +
   "usage:\n" +
   "  minilight modelFilePathName\n" +
   "\n" +
   "The model text file format is:\n" +
   "  #MiniLight\n" +
   "\n" +
   "  iterations\n" +
   "\n" +
   "  imagewidth imageheight\n" +
   "  viewposition viewdirection viewangle\n" +
   "\n" +
   "  skyemission groundreflection\n" +
   "\n" +
   "  vertex0 vertex1 vertex2 reflectivity emitivity\n" +
   "  vertex0 vertex1 vertex2 reflectivity emitivity\n" +
   "  ...\n" +
   "\n" +
   "- where iterations and image values are integers, viewangle is a real,\n" +
   "and all other values are three parenthised reals. The file must end\n" +
   "with a newline. E.g.:\n" +
   "  #MiniLight\n" +
   "\n" +
   "  10\n" +
   "\n" +
   "  100 75\n" +
   "  (0 0.75 -2) (0 0 1) 45\n" +
   "\n" +
   "  (3626 5572 5802) (0.1 0.09 0.07)\n" +
   "\n" +
   "  (0 0 0) (0 1 0) (1 1 0)  (0.7 0.7 0.7) (0 0 0)\n" +
   "\n"




#-- entry point ----------------------------------------------------------------

MODEL_FORMAT_ID = "#MiniLight"

begin

   # check if help message needed
   if ARGV.empty? || (ARGV[0] =~ /-(-help|\?)/)

      puts HELP

   # execute
   else

      puts BANNER

      # make random generator
      random = Hxa7241_MiniLight::Random.new

      # get file names
      modelFilePathname = ARGV[0]
      imageFilePathname = modelFilePathname + ".ppm"

      # open model file
      modelFile = File.new( modelFilePathname )

      # check model file format identifier at start of first line
      raise "invalid model file" if modelFile.readline !~ /^#{MODEL_FORMAT_ID}/

      # read frame iterations
      while (line = modelFile.readline.strip).empty? do end
      iterations = line.to_i

      # create top-level rendering objects with model file
      image  = Hxa7241_MiniLight::Image.new( modelFile )
      camera = Hxa7241_MiniLight::Camera.new( modelFile )
      scene  = Hxa7241_MiniLight::Scene.new( modelFile, camera.viewPosition )

      modelFile.close

      # do progressive refinement render loop
      1.upto( iterations ) do |frameNo|

         # display current frame number
         ($stdout << "\riteration: " << frameNo).flush

         # render a frame
         camera.getFrame?( scene, random, image )

         # save image at twice error-halving rate, and at start and end
         if ((frameNo & (frameNo - 1)) == 0) || (frameNo == iterations)
            # open image file
            File.open( imageFilePathname, "wb" ) do |imageFile|

               # write image frame to file
               image.getFormatted?( imageFile, frameNo )
            end
         end

      end

      puts "\nfinished"

   end

rescue Interrupt
   puts "\ninterrupted"

rescue Exception => e
   puts "\n*** execution failed:  #{e.message}\n" + e.backtrace.join("\n")

end
