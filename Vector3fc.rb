#------------------------------------------------------------------------------#
#                                                                              #
#  MiniLight Ruby : minimal global illumination renderer                       #
#  Harrison Ainsworth / HXA7241 : 2006-2008, 2013.                             #
#                                                                              #
#  http://www.hxa.name/minilight                                               #
#                                                                              #
#------------------------------------------------------------------------------#




module Hxa7241_MiniLight


# A constant 3D vector of Floats.
#
# Compact instead of efficient.
# Adapted from the HXA7241 JavaScript and C++ versions.
#
# Some methods are commented out, but they do work fine.
#
# ===invariants
# * @x is a Float
# * @y is a Float
# * @z is a Float
#
class Vector3fc

   # ===parameters options
   # can be one of:
   # * nothing
   # * an Array of objects with to_f defined
   # * a number of objects with to_f defined
   # * a String in the format (0.0 0.0 0.0)
   # * another Vector3fc
   #
   def initialize( *args )

      # string construction
      if (args.length == 1) && args[0].kind_of?( String )
         # (0.0 0.0 0.0)
         @x, @y, @z = (args[0].delete("()").split + [0,0,0]).map! { |e| e.to_f }

      # copy construction
      elsif args[0].kind_of?( Vector3fc )
         @x, @y, @z = args[0].x, args[0].y, args[0].z

      # conversion construction
      else
         args = args[0] if args[0].kind_of?( Array )

         # duplicate single argument or copy multiple arguments
         # default to zeros
         @x = @y = @z = args[0].to_f
         @y, @z = args[1].to_f, args[2].to_f if args.length > 1
      end

   end


#-- standard methods

  def to_a
     [@x, @y, @z]
  end


#  def to_s
#     sprintf( "(%g %g %g)", @x, @y, @z )
#  end
#
#
#  def eql?( other )
#     object_id.eql?( other.object_id ) ||
#        (other.kind_of?(Vector3fc) && ( self.to_a == other.to_a ))
#  end
#
#
#  def ==( other )
#     self.eql?( other )
#  end


   def isZero?
      (0.0 == @x) && (0.0 == @y) && (0.0 == @z)
   end


#-- read

   attr_reader :x, :y, :z


  def []( index )
      index == 2 ? @z : (index == 1 ? @y : @x)
#     case index.abs.modulo( 3 )
#        when 0 then @x
#        when 1 then @y
#        when 2 then @z
#     end
  end


#-- arithmetic producing reals
#-- (unary then binary)

#  def sum?
#     @x + @y + @z
#  end
#
#
#  def average?
#     sum? / 3.0
#  end
#
#
#  def smallest?
#     s = @x <= @y ? @x : @y
#     s <= @z ? s : @z
#  end
#
#
#  def largest?
#     l = @x >= @y ? @x : @y
#     l >= @z ? l : @z
#  end


#  def length?
#     Math.sqrt( dot?( self ) )
#  end
#
#
#  def distance?( v3f )
#     (self - v3f).length?
#  end


   def dot?( v3f )
      (@x * v3f.x) + (@y * v3f.y) + (@z * v3f.z)
   end


#-- arithmetic producing vectors
#-- (unary then binary)

   def -@
      Vector3fc.new( -@x, -@y, -@z )
   end


#  def abs?
#     Vector3fc.new( @x.abs, @y.abs, @z.abs )
#  end


   def unitize?
      length = Math.sqrt( dot?( self ) )
      self * (length != 0.0 ? 1.0 / length : 0.0)
   end


   def cross?( v3f )
      Vector3fc.new( (@y * v3f.z) - (@z * v3f.y),
                     (@z * v3f.x) - (@x * v3f.z),
                     (@x * v3f.y) - (@y * v3f.x) )
   end


   def +( arg )
      Vector3fc.new( (@x + arg.x), (@y + arg.y), (@z + arg.z) )
   end


   def -( arg )
      Vector3fc.new( (@x - arg.x), (@y - arg.y), (@z - arg.z) )
   end


   def *( arg )
      arg = Vector3fc.new( arg ) unless arg.kind_of?( Vector3fc )
      Vector3fc.new( (@x * arg.x), (@y * arg.y), (@z * arg.z) )
   end


#  def /( arg )
#     arg = Vector3fc.new( arg ) unless arg.kind_of?( Vector3fc )
#     Vector3fc.new( (@x / arg.x), (@y / arg.y), (@z / arg.z) )
#  end


#-- logical producing vectors

#  def <=>( arg )
#     combine?( arg ) { |a, b| a <=> b }
#  end
#
#
#  def eq?( arg )
#     combine?( arg ) { |a, b| a == b ? 1 : 0 }
#  end
#
#
#  def >( arg )
#     combine?( arg ) { |a, b| a >  b ? 1 : 0 }
#  end
#
#
#  def >=( arg )
#     combine?( arg ) { |a, b| a >= b ? 1 : 0 }
#  end
#
#
#  def <( arg )
#     combine?( arg ) { |a, b| a <  b ? 1 : 0 }
#  end
#
#
#  def <=( arg )
#     combine?( arg ) { |a, b| a <= b ? 1 : 0 }
#  end


#-- clamps

   def clampMin?( arg )
      combine?( arg ) { |a, b| a >= b ? a : b }
   end


   def clampMax?( arg )
      combine?( arg ) { |a, b| a <= b ? a : b }
   end


#  def clampBetween?( min, max )
#     clampMin?( min ).clampMax?( max )
#  end


   # 0 to almost 1, ie: [0,1).
   #
   def clamp01?
      clampMin?( ZERO ).clampMax?( Vector3fc.new( 1.0 - Float::EPSILON ) )
#     clampBetween?( ZERO, ALMOST_ONE )
   end


#-- implementation -------------------------------------------------------------

   def combine?( arg )
#     arg = Vector3fc.new( *args )

      Vector3fc.new( yield(@x, arg.x), yield(@y, arg.y), yield(@z, arg.z) )
   end


#-- constants ------------------------------------------------------------------

   ZERO       = Vector3fc.new( 0 )
#  HALF       = Vector3fc.new( 0.5 )
#  ONE        = Vector3fc.new( 1 )
#  EPSILON    = Vector3fc.new( Float::EPSILON )
#  ALMOST_ONE = Vector3fc.new( 1.0 - Float::EPSILON )
#  MIN        = Vector3fc.new( Float::MIN )
#  MAX        = Vector3fc.new( Float::MAX )
#  X          = Vector3fc.new( 1, 0, 0 )
#  Y          = Vector3fc.new( 0, 1, 0 )
#  Z          = Vector3fc.new( 0, 0, 1 )

   SCAN       = /\(.*?\)/

end


end # module Hxa7241_MiniLight
