#------------------------------------------------------------------------------#
#                                                                              #
#  MiniLight Ruby : minimal global illumination renderer                       #
#  Harrison Ainsworth / HXA7241 : 2006-2008, 2013.                             #
#                                                                              #
#  http://www.hxa.name/minilight                                               #
#                                                                              #
#------------------------------------------------------------------------------#


require 'Vector3fc'
require 'Triangle'
require 'SpatialIndex'




module Hxa7241_MiniLight


# A grouping of the objects in the environment.
#
# Makes a sub-grouping of emitting objects.
#
# Constant.
#
# ===invariants
# * @triangles        is an Array of Triangle length <= MAX_TRIANGLES
# * @emitters         is an Array of Triangle (refs) length <= MAX_TRIANGLES
# * @skyEmission      is a Vector3fc >= 0
# * @groundReflection is a Vector3fc >= 0 and < 1
# * @index            is a SpatialIndex
#
class Scene

   # ===parameters
   # * IO to read scene objects from
   # * Vector3fc eyePosition
   #
   def initialize( inStream, eyePosition )

      # read default sky and ground values
      while (vectors = inStream.readline.scan( Vector3fc::SCAN )).empty? do end

      # extract and condition default sky and ground values
      @skyEmission = Vector3fc.new( vectors[0] ).clampMin?( Vector3fc::ZERO )
      @groundReflection = Vector3fc.new( vectors[1] ).clamp01?

      # read triangles
      @triangles = Array.new
      begin
         MAX_TRIANGLES.times { @triangles << Triangle.new( inStream ) }
      rescue EOFError
         # EOF is not really exceptional here, but the code is simpler.
      end

      # find emitting triangles
      @emitters = @triangles.select do |triangle|
         # has non-zero emission and area
         !triangle.emitivity.isZero? && (triangle.area > 0.0)
      end

      # make index
      @index = SpatialIndex.new( eyePosition, @triangles );

   end


#-- queries --------------------------------------------------------------------

   # Find nearest intersection of ray with triangle.
   #
   # ===parameters
   # * rayOrigin Vector3fc
   # * rayDirection Vector3fc unitized
   # * lastHit Triangle previous intersected object
   #
   # ===return
   # Array of:
   # * Triangle object hit or nil
   # * Vector3fc hit position
   #
   def getIntersection?( rayOrigin, rayDirection, lastHit )

      @index.getIntersection?( rayOrigin, rayDirection, lastHit )

   end


   # Monte-carlo sample point on monte-carlo selected emitting triangle.
   #
   # ===parameters
   # * random Random generator
   #
   # ===return
   # Array of:
   # * Vector3fc position
   # * Triangle  object ref
   #
   def getEmitter?( random )

      # select emitter
      emitter = !@emitters.empty? ? @emitters[ [@emitters.length - 1,
         (random.real64 * @emitters.length).to_i].min ] : nil

      # get position on triangle
      [ (emitter ? emitter.getSamplePoint?(random) : Vector3fc::ZERO), emitter ]

   end


   # Number of emitters in scene.
   #
   def emittersCount

      @emitters.length

   end


   # Default/'background' light of scene universe.
   #
   # ===parameters
   # * backDirection Vector3fc direction from emitting point
   #
   # ===return
   # Vector3f emitted radiance
   #
   def getDefaultEmission?( backDirection )

      # sky for downward ray, ground for upward ray
      backDirection.y < 0.0 ? @skyEmission : @skyEmission * @groundReflection

   end


#-- constants ------------------------------------------------------------------

   # 2^24 ~= 16 million
   MAX_TRIANGLES = 0x1000000

end


end # module Hxa7241_MiniLight
