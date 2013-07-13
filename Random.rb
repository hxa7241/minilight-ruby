#------------------------------------------------------------------------------#
#                                                                              #
#  MiniLight Ruby : minimal global illumination renderer                       #
#  Harrison Ainsworth / HXA7241 : 2006-2008, 2013.                             #
#                                                                              #
#  http://www.hxa.name/minilight                                               #
#                                                                              #
#------------------------------------------------------------------------------#




module Hxa7241_MiniLight


# Simple, fast, good random number generator.
#
# Constant (sort-of: internally/non-semantically modifying).
#
# ===implementation
# 'Maximally Equidistributed Combined Tausworthe Generators'; L'Ecuyer; 1996.
# http://www.iro.umontreal.ca/~lecuyer/myftp/papers/tausme2.ps
# http://www.iro.umontreal.ca/~simardr/rng/lfsr113.c
#
# 'Conversion of High-Period Random Numbers to Floating Point'; Doornik; 2006.
# http://www.doornik.com/research/randomdouble.pdf
#
# ===invariants
# * @state_  are Integers >= 0 and < 2^32 (32-bit int unsigned range)
# * @id is a String of 8 chars
#
class Random

   #def initialize()

   #  # Unix time -- signed 32-bit, seconds since 1970
   #  # make unsigned, with 2s-comp bit-pattern
   #  # rotate to make frequently changing bits more significant
   #  time = Time.now.to_i % 4294967296
   #  seed = ((time << 8) | (time >> 24)) & 0xFFFFFFFF

   #  # *** VERY IMPORTANT ***
   #  # The initial seeds z1, z2, z3, z4  MUST be larger
   #  # than 1, 7, 15, and 127 respectively.
   #  sa = Array.new(4) { |i| (seed >= SEED_MINS[i]) ? seed : SEED }

   #  @state0, @state1, @state2, @state3 = sa

   #  # store seed/id as 8 digit hex number string
   #  @id = sprintf( "%08X", @state3 & 0xFFFFFFFF )

   #end

   def initialize()

     # *** VERY IMPORTANT ***
     # The initial seeds z1, z2, z3, z4  MUST be larger
     # than 1, 7, 15, and 127 respectively.
     @state0 = @state1 = @state2 = @state3 = SEED

   end


#-- queries --------------------------------------------------------------------

   # Random integer, 32-bit unsigned.
   #
   # (unrolled implementation is faster)
   #
   # ===return
   # Integer >= 0 and < 2^32
   #
   def int32u

      @state0 = (((@state0 & 0xFFFFFFFE) << 18) & 0xFFFFFFFF) ^
                ((((@state0 <<  6) & 0xFFFFFFFF) ^ @state0) >> 13)
      @state1 = (((@state1 & 0xFFFFFFF8) <<  2) & 0xFFFFFFFF) ^
                ((((@state1 <<  2) & 0xFFFFFFFF) ^ @state1) >> 27)
      @state2 = (((@state2 & 0xFFFFFFF0) <<  7) & 0xFFFFFFFF) ^
                ((((@state2 << 13) & 0xFFFFFFFF) ^ @state2) >> 21)
      @state3 = (((@state3 & 0xFFFFFF80) << 13) & 0xFFFFFFFF) ^
                ((((@state3 <<  3) & 0xFFFFFFFF) ^ @state3) >> 12)
      
      @state0 ^ @state1 ^ @state2 ^ @state3

   end


   # Random real, [0,1) double-precision.
   #
   # ===return
   # Float in [0,1) range (never returns 1)
   #
   def real64

      int0, int1 = int32u, int32u

      (((int0 < 2147483648) ? int0 : (int0 - 4294967296)).to_f *
        (1.0 / 4294967296.0)) + 0.5 + 
        ((int1 & 0x001FFFFF).to_f * (1.0 / 9007199254740992.0))

   end


   #attr_reader :id


#-- constants ------------------------------------------------------------------

   # default seed
   SEED = 987654321

   # minimum seeds
   #SEED_MINS = [ 2, 8, 16, 128 ]

end


end # module Hxa7241_MiniLight
