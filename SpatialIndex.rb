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


# A minimal spatial index for ray tracing.
#
# Suitable for a scale of 1 metre == 1 numerical unit, and has a resolution of
# 1 millimetre. (Implementation uses fixed tolerances.)
#
# Constant.
#
# ===implementation
# A degenerate State pattern: typed by @isBranch field to be either a branch
# or leaf cell.
#
# Octree: axis-aligned, cubical. Subcells are numbered thusly:
#            110---111
#            /|    /|
#         010---011 |
#    y z   | 100-|-101
#    |/    |/    | /
#    .-x  000---001
#
# Each cell stores its bound: fatter data, but simpler code.
#
# Calculations for building and tracing are absolute rather than incremental --
# so quite numerically solid. Uses tolerances in: bounding triangles (in
# Triangle.getBound), and checking intersection is inside cell (both effective
# for axis-aligned items). Also, depth is constrained to an absolute subcell
# size (easy way to handle overlapping items).
#
# The code is somewhat expanded (extra nine lines) by moderate manual
# optimization (three times faster in places).
#
# ===invariants
# * @bound is an Array of 6 Floats
# * @bound[0-2] <= @bound[3-5]
# * @bound encompasses the cell's contents
# if @isBranch
# * @vector length is 8
# * @vector elements are nil or SpatialIndex pointers
# else
# * @vector elements are non-nil Triangle pointers
#
class SpatialIndex

   # ===parameters
   # * arg Vector3fc (eyePosition)
   # * items Array of Triangle
   # or
   # * arg Array of 6 floats (bound)
   # * items Array of Hash of {bound, Triangle}
   # * level Numeric
   #
   def initialize( arg, items, level = 0 )

      # set the overall bound, if root call of recursion
      @bound = if arg.is_a?( Vector3fc )
         # make all item bounds
         items = items.map { |item| {:bound => item.getBound?, :item => item} }

         # accommodate all items, and eye position (makes tracing algorithm
         # simpler)
         bound = items.inject( [arg.to_a, arg.to_a].flatten ) do |b, item|
            b.each_index do |j|
               b[j] = item[:bound][j] if (b[j] > item[:bound][j]) ^ (j > 2)
            end
         end

         # make cubical
         size = (Vector3fc.new(bound[3,3]) - Vector3fc.new(bound[0,3])).to_a.max
         bound[0,3] + (Vector3fc.new(bound[3,3]).clampMin?(
            Vector3fc.new(bound[0,3]) + Vector3fc.new(size) )).to_a
      end || arg

      # is branch if items overflow leaf and tree not too deep
      @isBranch = (items.length > MAX_ITEMS) && (level < (MAX_LEVELS - 1))

      # be branch: make sub-cells, and recurse construction
      if @isBranch

         # make subcells
         q1 = 0
         @vector = Array.new( 8 ) do |s|

            # make subcell bound
            subBound = Array.new( 6 ) do |j|
               m = j % 3
               (((s >> m) & 1) != 0) ^ (j > 2) ?
                  (@bound[m] + @bound[m + 3]) * 0.5 : @bound[j]
            end

            # collect items that overlap subcell
            subItems = items.select do |item|
               itemBound = item[:bound]

               # must overlap in all dimensions
               (itemBound[3] >= subBound[0]) & (itemBound[0] < subBound[3]) &
                  (itemBound[4] >= subBound[1]) & (itemBound[1] < subBound[4]) &
                  (itemBound[5] >= subBound[2]) & (itemBound[2] < subBound[5])
            end

            # curtail degenerate subdivision by adjusting next level
            # (degenerate if two or more subcells copy entire contents of
            # parent, or if subdivision reaches below mm size)
            # (having a model including the sun requires one subcell copying
            # entire contents of parent to be allowed)
            q1 += ((subItems.length == items.length) ? 1 : 0)
            q2  = (subBound[3] - subBound[0]) < (Triangle::TOLERANCE * 4.0)

            # recurse
            !subItems.empty? ? SpatialIndex.new( subBound, subItems,
               ((q1 > 1) | q2 ? MAX_LEVELS : level + 1) ) : nil

         end

      # be leaf: store items, and end recursion
      # (trim reserve capacity ?)
      end || @vector = Array.new( items.length ) { |i| items[i][:item] }

   end


#-- queries --------------------------------------------------------------------

   # Find nearest intersection of ray with item.
   #
   # ===parameters
   # * rayOrigin Vector3fc
   # * rayDirection Vector3fc
   # * lastHit Triangle previous intersected item
   # * start Vector3fc traversal position
   #
   # ===return
   # Array of:
   # * Triangle  item intersected or nil
   # * Vector3fc position of intersection or nil
   #
   def getIntersection?( rayOrigin, rayDirection, lastHit, start = rayOrigin )

      hitObject = hitPosition = nil

      # is branch: step through subcells and recurse
      if @isBranch

         # find which subcell holds ray origin (ray origin is inside cell)
         # compare dimension with center
         subCell = (start[0] >= ((@bound[0] + @bound[3]) * 0.5)) ? 1 : 0
         subCell |= 2 if start[1] >= ((@bound[1] + @bound[4]) * 0.5)
         subCell |= 4 if start[2] >= ((@bound[2] + @bound[5]) * 0.5)

         # step through intersected subcells
         cellPosition = start
         loop do

            if @vector[subCell]
               # intersect subcell
               hitObject, hitPosition = @vector[subCell].getIntersection?(
                  rayOrigin, rayDirection, lastHit, cellPosition )
               # exit if item hit
               break if hitObject
            end

            # find next subcell ray moves to
            # (by finding which face of the corner ahead is crossed first)
            step = Float::MAX;  axis = 0
            3.times do |i|
               high = (subCell >> i) & 1
               face = (rayDirection[i] < 0.0) ^ (0 != high) ?
                  @bound[i + (high * 3)] : (@bound[i] + @bound[i + 3]) * 0.5
               distance = (face - rayOrigin[i]) / rayDirection[i]

               if distance <= step then step = distance; axis = i end
            end

            # leaving branch if: subcell is low and direction is negative,
            # or subcell is high and direction is positive
            break if (((subCell >> axis) & 1) == 1) ^ (rayDirection[axis] < 0.0)

            # move to (outer face of) next subcell
            cellPosition = rayOrigin + (rayDirection * step)
            subCell      = subCell ^ (1 << axis)

         end

      # is leaf: exhaustively intersect contained items
      else

         nearestDistance = Float::MAX

         # step through items
         @vector.each do |item|
            # avoid false intersection with surface just come from
            unless item.equal?( lastHit )

               # intersect ray with item, and inspect if nearest so far
               distance = item.getIntersection?( rayOrigin, rayDirection )
               if distance && (distance < nearestDistance)

                  # check intersection is inside cell bound (with tolerance)
                  hit = rayOrigin + (rayDirection * distance)
                  t = Triangle::TOLERANCE
                  if (@bound[0] - hit[0] <= t) && (hit[0] - @bound[3] <= t) &&
                     (@bound[1] - hit[1] <= t) && (hit[1] - @bound[4] <= t) &&
                     (@bound[2] - hit[2] <= t) && (hit[2] - @bound[5] <= t)

                     hitObject, hitPosition = item, hit
                     nearestDistance = distance
                  end

               end

            end
         end

      end

      [hitObject, hitPosition]

   end


#-- constants ------------------------------------------------------------------

   # accommodates scene including sun and earth, down to cm cells
   # (use 47 for mm)
   MAX_LEVELS = 44
   MAX_ITEMS  =  8

end


end # module Hxa7241_MiniLight
