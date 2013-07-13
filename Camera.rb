#------------------------------------------------------------------------------#
#                                                                              #
#  MiniLight Ruby : minimal global illumination renderer                       #
#  Harrison Ainsworth / HXA7241 : 2006-2008, 2013.                             #
#                                                                              #
#  http://www.hxa.name/minilight                                               #
#                                                                              #
#------------------------------------------------------------------------------#


require 'Vector3fc'
require 'RayTracer'




module Hxa7241_MiniLight


# A view with rasterization capability.
#
# Constant.
#
# ===invariants
# * @viewAngle     is a float >= VIEW_ANGLE_MIN and <= VIEW_ANGLE_MAX degrees
#                  in radians
# * @viewPosition  is a Vector3fc
# * @viewDirection is a Vector3fc unitized
# * @right         is a Vector3fc unitized
# * @up            is a Vector3fc unitized
# * above three form a coordinate frame
#
class Camera

   # ===parameters
   # * inStream IO to read camera settings from
   #
   def initialize( inStream )

      # read view definition
      while (line = inStream.readline.strip).empty? do end
      vectors, viewAngle = line.scan(Vector3fc::SCAN), line.match(/\d+?$/)[0]

      # extract and condition view definition
      @viewPosition  = Vector3fc.new( vectors[0] )
      @viewDirection = Vector3fc.new( vectors[1] ).unitize?
      @viewDirection = Vector3fc.new( 0, 0, 1 ) if @viewDirection.isZero?
      @viewAngle     = [VIEW_ANGLE_MAX, [VIEW_ANGLE_MIN, viewAngle.to_f].max
         ].min * (Math::PI / 180.0)

      # make other directions of frame
      @up    = Vector3fc.new( 0, 1, 0 )
      @right = @up.cross?( @viewDirection ).unitize?

      unless @right.isZero?
         @up    = @viewDirection.cross?( @right ).unitize?
      else
         @up    = Vector3fc.new( 0, 0, @viewDirection.y < 0 ? 1 : -1 )
         @right = @up.cross?( @viewDirection ).unitize?
      end

   end


#-- queries --------------------------------------------------------------------

   # Accumulate a new frame to the image.
   #
   # ===parameters
   # * scene  Scene to read from
   # * random Random generator
   # * image  Image to write to
   #
   def getFrame?( scene, random, image )

      rayTracer = RayTracer.new( scene )

      aspect = image.height.to_f / image.width.to_f

      # do image sampling pixel loop
      image.height.times do |y|
         image.width.times do |x|

            # make sample ray direction, stratified by pixels

            # make image plane displacement vector coefficients
            xCoefficient = ((x + random.real64) * 2.0 / image.width ) - 1.0
            yCoefficient = ((y + random.real64) * 2.0 / image.height) - 1.0

            # make image plane offset vector
            offset = (@right * xCoefficient) + (@up * (yCoefficient * aspect))

            sampleDirection = (@viewDirection +
               (offset * Math.tan(@viewAngle * 0.5))).unitize?

            # get radiance from RayTracer
            radiance = rayTracer.getRadiance?( @viewPosition, sampleDirection,
               random )

            # add radiance to pixel
            image.addToPixel!( x, y, radiance )

         end
      end

   end


   attr_reader :viewPosition


#-- constants ------------------------------------------------------------------

   # View angle range, in degrees.
   VIEW_ANGLE_MIN =  10
   VIEW_ANGLE_MAX = 160

end


end # module Hxa7241_MiniLight
