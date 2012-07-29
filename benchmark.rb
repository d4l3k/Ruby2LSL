require 'fastruby'
require 'benchmark'
class X
  fastruby '
  def fibi
    a = 0
    b = 1
    10000.times do
      tmp = a+b
      a=b
      b=tmp
    end
  end
  '
  def fibi_slow
    a = 0
    b = 1
    10000.times do
      tmp = a+b
      a=b
      b=tmp
    end
  end
end

Benchmark.bm do |bench|
  bench.report("fast") { X.new.fibi }
  bench.report("slow") { X.new.fibi_slow }
end
