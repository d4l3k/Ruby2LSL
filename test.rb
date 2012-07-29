require("test2")

module Potato
  Potato::football = 12
  def say_something
    puts "ERMAHGERD PERTATERS!"
    puts "PERFOOTBLLLZ #{Potato::football} #{Potato::flip}"
    state ThisOtherOne
  end
  def flip
    return "Foop"
  end
  def test
    extern_lsl '
      integer i;
      for(i=0;i<16;i++)
      {
        llOwnerSay("Boop");
      }
    '
    b = [1,5,7,0]
    c = [1..17]
  end
end

class Default < State
  def state_entry
    potato = 5
    potato += 9
    c = "silly little people #{potato}"
    puts "Hello world! There are some #{c}"
    puts "This is a number #{5 + 5 + potato} and then an embedded function: #{llToUpper("dolfin")}"
    puts c
  end
  def touch_start num_detected
    banana_lama = (1 + 2 + 3 ) * 6 - 36
    puts "#{num_detected} people touched me! OMG! the first guy was #{llDetectedName(banana_lama)}, what a weirdo!"
  end
  def touch_end num_detected
    Potato::test
    Potato::say_something
  end
end

class ThisOtherOne < State
  def state_entry
    puts "Boop"
    Test2::hello()
    if 5==5
      puts "If passes."
      puts "another test."
    end
  end
end
