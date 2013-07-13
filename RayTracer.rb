#------------------------------------------------------------------------------#
#                                                                              #
#  MiniLight Ruby : minimal global illumination renderer                       #
#  Harrison Ainsworth / HXA7241 : 2006-2008, 2013.                             #
#                                                                              #
#  http://www.hxa.name/minilight                                               #
#                                                                              #
#------------------------------------------------------------------------------#


require 'Vector3fc'
require 'SurfacePoint'




module Hxa7241_MiniLight


# Ray tracer for general light transport.
#
# Traces a path with emitter sampling each step: A single chain of ray-steps
# advances from the eye into the scene with one sampling of emitters at each
# node.
#
# Constant.
#
# ===invariants
# * @sceneRef is a Scene reference
#
class RayTracer

   def initialize( scene )

      @sceneRef = scene

   end


#-- queries --------------------------------------------------------------------

   # Returned radiance from a trace.
   #
   # ===parameters
   # * rayOrigin Vector3fc ray start point
   # * rayDirection Vector3fc ray direction unitized
   # * random Random generator
   # * lastHit Triangle a ref to the previous intersected object in the scene
   #
   # ===return
   # Vector3f radiance back along ray direction
   #
   def getRadiance?( rayOrigin, rayDirection, random, lastHit = nil )

      # intersect ray with scene
      hitRef, hitPosition = @sceneRef.getIntersection?( rayOrigin, rayDirection,
         lastHit )

      if hitRef
         # make surface point of intersection
         surfacePoint = SurfacePoint.new( hitRef, hitPosition )

         # local emission only for first-hit
         localEmission = lastHit ? Vector3fc::ZERO :
            surfacePoint.getEmission?( rayOrigin, -rayDirection, false )

         # emitter sample
         illumination = sampleEmitters?( rayDirection, surfacePoint, random )

         # recursive reflection:
         # single hemisphere sample, ideal diffuse BRDF:
         # reflected = (inradiance * pi) * (cos(in) / pi * color) * reflectance
         # -- reflectance magnitude is 'scaled' by the russian roulette, cos is
         # importance sampled (both done by SurfacePoint), and the pi and 1/pi
         # cancel out
         nextDirection, color = surfacePoint.getNextDirection?( random,
            -rayDirection )
         # check surface bounces ray
         reflection = if !nextDirection.isZero?

            # recurse
            color * getRadiance?( surfacePoint.position, nextDirection, random,
               surfacePoint.triangleRef )

         end || Vector3fc::ZERO

         # total radiance returned
         reflection + illumination + localEmission

      # no hit: default/background scene emission
      end || @sceneRef.getDefaultEmission?( -rayDirection )

   end


#-- implementation -------------------------------------------------------------
private

   # Radiance from an emitter sample.
   #
   # ===parameters
   # * rayDirection Vector3fc ray direction unitized
   # * surfacePoint SurfacePoint
   # * random Random generator
   #
   # ===return
   # Vector3f radiance back along ray direction
   #
   def sampleEmitters?( rayDirection, surfacePoint, random )

      # single emitter sample, ideal diffuse BRDF:
      # reflected = (emitivity * solidangle) * (emitterscount) *
      # (cos(emitdirection) / pi * reflectivity)
      # -- SurfacePoint does the first and last parts (in separate methods)

      # check an emitter is found
      emitterPosition, emitterRef = @sceneRef.getEmitter?( random )
      if emitterRef

         # make direction to emit point
         emitDirection = (emitterPosition - surfacePoint.position).unitize?

         # send shadow ray
         hitRef, p = @sceneRef.getIntersection?( surfacePoint.position,
            emitDirection, surfacePoint.triangleRef )

         # if unshadowed, get inward emission value
         emissionIn = if !hitRef || emitterRef.equal?( hitRef )
            SurfacePoint.new( emitterRef, emitterPosition ).getEmission?(
               surfacePoint.position, -emitDirection, true )
         end || Vector3fc::ZERO

         # get amount reflected by surface
         surfacePoint.getReflection?( emitDirection,
            (emissionIn * @sceneRef.emittersCount), -rayDirection )

      end || Vector3fc::ZERO

   end

end


end # module Hxa7241_MiniLight
