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


# Surface point at a ray-object intersection.
#
# All direction parameters are away from surface.
#
# Constant.
#
# ===invariants
# * @triangleRef is a Triangle reference (non-owned), not nil
# * @position    is a Vector3fc
#
class SurfacePoint

   # ===parameters
   # * triangle Triangle
   # * position Vector3fc
   #
   def initialize( triangle, position )

      @triangleRef = triangle
      @position    = Vector3fc.new( position )

   end


#-- queries --------------------------------------------------------------------

   # Emission from surface element to point.
   #
   # ===parameters
   # * toPosition Vector3fc point being illuminated
   # * outDirection Vector3fc direction unitized from emitting point
   # * isSolidAngle boolean is solid angle used
   #
   # ===return
   # Vector3f emitted radiance
   #
   def getEmission?( toPosition, outDirection, isSolidAngle )

      ray       = toPosition - @position
      distance2 = ray.dot?( ray )
      cosArea   = outDirection.dot?(@triangleRef.normal) * @triangleRef.area

      # clamp-out infinity
      solidAngle = isSolidAngle ?
         cosArea / (distance2 >= 1e-6 ? distance2 : 1e-6) : 1

      # front face of triangle only
      cosArea > 0.0 ? (@triangleRef.emitivity * solidAngle) : Vector3fc::ZERO

   end


   # Light reflection from ray to ray by surface.
   #
   # ===parameters
   # * inDirection Vector3fc negative of inward ray direction
   # * inRadiance Vector3fc inward radiance
   # * outDirection Vector3fc outward ray (towards eye) direction
   #
   # ===return
   # Vector3f reflected radiance
   #
   def getReflection?( inDirection, inRadiance, outDirection )

      inDot = inDirection.dot?( @triangleRef.normal )

      # directions must be on same side of surface
      unless (inDot < 0.0) ^ (outDirection.dot?( @triangleRef.normal ) < 0.0)

         # ideal diffuse BRDF:
         # radiance scaled by cosine, 1/pi, and reflectivity
         inRadiance * @triangleRef.reflectivity * (inDot.abs / Math::PI)

      end || Vector3fc::ZERO

   end


   # Monte-carlo direction of reflection from surface.
   #
   # ===parameters
   # * random Random generator
   # * inDirection Vector3fc eyeward ray direction
   #
   # ===return
   # Array of:
   # * Vector3fc sceneward ray direction unitized
   # * Vector3fc color of interaction point
   #
   def getNextDirection?( random, inDirection )

      reflectivityMean =
         @triangleRef.reflectivity.dot?( Vector3fc.new( 1.0 ) ) / 3.0

      # russian-roulette for reflectance magnitude
      if random.real64 < reflectivityMean

         color = @triangleRef.reflectivity * (1.0 / reflectivityMean)

         # cosine-weighted importance sample hemisphere

         _2pr1, sr2 = (Math::PI * 2.0 * random.real64), Math.sqrt(random.real64)

         # make coord frame coefficients (z in normal direction)
         x, y = (Math.cos(_2pr1) * sr2), (Math.sin(_2pr1) * sr2)
         z    = Math.sqrt( 1.0 - (sr2 * sr2) )

         # make coord frame
         normal, tangent = @triangleRef.normal, @triangleRef.tangent
         # enable reflection from either face of surface
         normal = normal.dot?( inDirection ) >= 0.0 ? normal : -normal

         # make vector from frame times coefficients
         outDirection = (tangent * x) + (normal.cross?( tangent ) * y) +
            (normal * z)

         [ outDirection, color ]

      end || [ Vector3fc::ZERO, Vector3fc::ZERO ]

   end


   attr_reader :triangleRef, :position

end


end # module Hxa7241_MiniLight
