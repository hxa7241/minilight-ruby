#------------------------------------------------------------------------------#
#                                                                              #
#  MiniLight Ruby : minimal global illumination renderer                       #
#  Harrison Ainsworth / HXA7241 : 2006-2008, 2013.                             #
#                                                                              #
#  http://www.hxa.name/minilight                                               #
#                                                                              #
#------------------------------------------------------------------------------#


require 'Vector3fc'




module Hxa7241_MiniLight


# Pixel sheet with simple tone-mapping and file formatting.
#
# ===references
# Uses PPM image format:
# <cite>http://netpbm.sourceforge.net/doc/ppm.html</cite>
#
# Uses Ward simple tonemapper:
# <cite>'A Contrast Based Scalefactor For Luminance Display'
# Ward;
# Graphics Gems 4, AP 1994.</cite>
#
# ===invariants
# * @width  is an Integer >= 1 and <= IMAGE_DIM_MAX
# * @height is an Integer >= 1 and <= IMAGE_DIM_MAX
# * @pixels is an Array of Floats, length == (@width * @height * 3)
#
class Image

   # ===parameters
   # * inStream IO to read image settings from
   #
   def initialize( inStream )

      # read and condition width and height
      while (dimensions = inStream.readline.scan(/\b\d+\b/)).empty? do end
      @width  = [IMAGE_DIM_MAX, [1, dimensions[0].to_i].max].min
      @height = [IMAGE_DIM_MAX, [1, dimensions[1].to_i].max].min

      # make pixel array
      @pixels = Array.new( @width * @height * 3, 0.0 )

   end


#-- commands -------------------------------------------------------------------

   # Accumulate (add, not just assign) a value to the image.
   #
   # ===parameters
   # * x Numeric x coord
   # * y Numeric y coord
   # * radiance Vector3fc to add
   #
   def addToPixel!( x, y, radiance )

      if (x >= 0) && (x < @width) && (y >= 0) && (y < @height)
         index = (x + ((@height - 1 - y) * @width)) * 3
         radiance.to_a.each { |a| @pixels[index] += a; index += 1 }
      end

   end


#-- queries --------------------------------------------------------------------

   attr_reader :width, :height


   # Format the image.
   #
   # ===parameters
   # * out IO to receive the image
   # * iteration Numeric number of accumulations made to the image
   #
   def getFormatted?( out, iteration )

      divider = 1.0 / (iteration >= 1 ? iteration : 1)

      tonemapScaling = Image::calculateToneMapping( @pixels, divider )

      # write ID and comment
      out << PPM_ID << "\n" << "# " << MINILIGHT_URI << "\n\n"

      # write width, height, maxval
      out << @width <<  " " << @height << "\n" << 255 << "\n"

      # write pixels
      @pixels.each do |channel|
         # tonemap
         mapped = channel * divider * tonemapScaling

         # gamma encode
         gammaed = (mapped > 0.0 ? mapped : 0.0) ** GAMMA_ENCODE

         # quantize and output as byte
         out.putc( [(gammaed * 255.0) + 0.5, 255.0].min.to_i & 0xFF )
      end

   end


#-- implementation -------------------------------------------------------------
private

   # Calculate tone-mapping scaling factor.
   #
   # ===parameters
   # * pixels Array of Floats
   # * divider Float pixel scaling factor
   #
   # ===return
   # Float scaling factor
   #
   def self.calculateToneMapping( pixels, divider )

      # calculate estimate of world-adaptation luminance
      # as log mean luminance of scene
      sumOfLogs = 0.0
      (pixels.length / 3).times do |i|
         y = Vector3fc.new( pixels[i * 3, 3] ).dot?( RGB_LUMINANCE ) * divider
         sumOfLogs += Math.log10( y > 1e-4 ? y : 1e-4 )
      end

      adaptLuminance = 10.0 ** (sumOfLogs / (pixels.length / 3))

      # make scale-factor from:
      # ratio of minimum visible differences in luminance, in display-adapted
      # and world-adapted perception (discluding the constant that cancelled),
      # divided by display max to yield a [0,1] range
      a = 1.219 + (DISPLAY_LUMINANCE_MAX * 0.25) ** 0.4
      b = 1.219 + adaptLuminance ** 0.4

      ((a / b) ** 2.5) / DISPLAY_LUMINANCE_MAX

   end


#-- constants ------------------------------------------------------------------

   # Image dimension maximum: for both width and height.
   IMAGE_DIM_MAX         = 4000

   # format items
   PPM_ID                = "P6"
   MINILIGHT_URI         = "http://www.hxa.name/minilight"

   # guess of average screen maximum brightness
   DISPLAY_LUMINANCE_MAX = 200.0

   # ITU-R BT.709 standard RGB luminance weighting
   RGB_LUMINANCE         = Vector3fc.new( 0.2126, 0.7152, 0.0722 )

   # ITU-R BT.709 standard gamma
   GAMMA_ENCODE          = 0.45

end


end # module Hxa7241_MiniLight
