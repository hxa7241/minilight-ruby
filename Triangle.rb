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


# A simple, explicit/non-vertex-shared triangle.
#
# Includes geometry and quality.
#
# Constant.
#
# (Much is precalculated and stored to speed it all up.)
#
# ===references
# Adapts ray intersection code from:
# <cite>'Fast, Minimum Storage Ray-Triangle Intersection'
# Moller, Trumbore;
# Journal of Graphics Tools, v2 n1 p21, 1997.
# http://www.acm.org/jgt/papers/MollerTrumbore97/</cite>
#
# ===invariants
# * @vertexs      is an Array of 3 Vector3fc
# * @edge0        is a Vector3fc
# * @edge3        is a Vector3fc
# * @reflectivity is a Vector3fc >= 0 and < 1
# * @emitivity    is a Vector3fc >= 0
# * @tangent      is a Vector3fc unitized
# * @normal       is a Vector3fc unitized
# * @area         is a Float
#
class Triangle

   # ===parameters
   # * inStream IO to read from
   #
   def initialize( inStream )

      # read data
      while (vectors = inStream.readline.scan( Vector3fc::SCAN )).empty? do end

      # extract geometry
      @vertexs = vectors[0,3].map! { |v| Vector3fc.new( v ) }
      @edge0   = Vector3fc.new( vectors[1] ) - Vector3fc.new( vectors[0] )
      @edge3   = Vector3fc.new( vectors[2] ) - Vector3fc.new( vectors[0] )

      # extract and condition quality
      @reflectivity = Vector3fc.new( vectors[3] ).clamp01?
      @emitivity    = Vector3fc.new( vectors[4] ).clampMin?( Vector3fc::ZERO )

      # set derived attributes
      edge1    = Vector3fc.new( vectors[2] ) - Vector3fc.new( vectors[1] )
      @tangent = @edge0.unitize?
      @normal  = @tangent.cross?( edge1 ).unitize?
      # (half area of parallelogram)
      pa2   = @edge0.cross?( edge1 )
      @area = Math.sqrt( pa2.dot?(pa2) ) * 0.5

   end


#-- queries --------------------------------------------------------------------

   # Axis-aligned bounding box of triangle.
   #
   # ===implementation
   # Written in a low-level style: verbose (extra 12 lines), but much faster.
   #
   # ===return
   # * Array of 6 float, lower corner in [0..2], and upper corner in [3..5]
   #
   def getBound?

      v2 = @vertexs[2]
      bound = [ v2.x, v2.y, v2.z, v2.x, v2.y, v2.z ]

      3.times do |j|
         v0 = @vertexs[0][j]
         v1 = @vertexs[1][j]
         if v0 < v1
            bound[    j] = v0 if v0 < bound[    j]
            bound[3 + j] = v1 if v1 > bound[3 + j]
         else
            bound[    j] = v1 if v1 < bound[    j]
            bound[3 + j] = v0 if v0 > bound[3 + j]
         end
         bound[    j] -= TOLERANCE
         bound[3 + j] += TOLERANCE
      end

      bound

   end


   # Intersection point of ray with triangle.
   #
   # ===implementation
   # Manually inlined all vector operations (is much faster).
   #
   # ===parameters
   # * rayOrigin Vector3fc
   # * rayDirection Vector3fc
   #
   # ===return
   # * Float distance or nil
   #
   def getIntersection?( rayOrigin, rayDirection )

      # find vectors for two edges sharing vert0
      #edge1 = vert1 - vert0
      #edge2 = vert2 - vert0
      e1x = @edge0.x;  e1y = @edge0.y;  e1z = @edge0.z
      e2x = @edge3.x;  e2y = @edge3.y;  e2z = @edge3.z

      # begin calculating determinant - also used to calculate U parameter
      #pvec = rayDirection.cross?( edge2 )
      pvx = (rayDirection.y * e2z) - (rayDirection.z * e2y)
      pvy = (rayDirection.z * e2x) - (rayDirection.x * e2z)
      pvz = (rayDirection.x * e2y) - (rayDirection.y * e2x)

      # if determinant is near zero, ray lies in plane of triangle
      #det = edge1.dot?( pvec )
      det = (e1x * pvx) + (e1y * pvy) + (e1z * pvz)

      return nil if det > -EPSILON && det < EPSILON

      inv_det = 1.0 / det

      # calculate distance from vert0 to ray origin
      #tvec = rayOrigin - @vertexs[0]
      v0 = @vertexs[0]
      tvx = rayOrigin.x - v0.x
      tvy = rayOrigin.y - v0.y
      tvz = rayOrigin.z - v0.z

      # calculate U parameter and test bounds
      #u = tvec.dot?( pvec ) * inv_det
      u = ((tvx * pvx) + (tvy * pvy) + (tvz * pvz)) * inv_det
      return nil if u < 0.0 || u > 1.0

      # prepare to test V parameter
      #qvec = tvec.cross?( edge1 )
      qvx = (tvy * e1z) - (tvz * e1y)
      qvy = (tvz * e1x) - (tvx * e1z)
      qvz = (tvx * e1y) - (tvy * e1x)

      # calculate V parameter and test bounds
      #v = rayDirection.dot?( qvec ) * inv_det
      v = ((rayDirection.x * qvx) + (rayDirection.y * qvy) +
         (rayDirection.z * qvz)) * inv_det
      return nil if v < 0.0 || (u + v > 1.0)

      # calculate t, ray intersects triangle
      #t = edge2.dot?( qvec ) * inv_det
      t = ((e2x * qvx) + (e2y * qvy) + (e2z * qvz)) * inv_det

      # only allow intersections in the forward ray direction
      t >= 0.0 ? t : nil

   end


   # Monte-carlo sample point on triangle.
   #
   # ===parameters
   # * random Random generator
   #
   # ===return
   # Vector3f
   #
   def getSamplePoint?( random )

      # get two randoms
      sqr1, r2 = Math.sqrt(random.real64), random.real64

      # make barycentric coords
      a, b = (1.0 - sqr1), ((1.0 - r2) * sqr1)
      #c = r2 * sqr1

      # make position by scaling edges by barycentrics
      (@edge0 * a) + (@edge3 * b) + @vertexs[0]

   end


   attr_reader :reflectivity, :emitivity, :normal, :tangent, :area


#-- constants ------------------------------------------------------------------

   TOLERANCE = 1.0 / 1024.0
   EPSILON   = 1.0 / 1048576.0

end


end # module Hxa7241_MiniLight
