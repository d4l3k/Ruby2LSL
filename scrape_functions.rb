require "net/http"
require "yaml"
data = Net::HTTP.get_response(URI.parse("http://wiki.secondlife.com/wiki/Category:LSL_Functions")).body
links = []
split = data.split("<a href=\"")
split.delete_at(0)
split.each do |dat|
	split2 = dat.split("\"")
	if split2[0][6..7]=="Ll"
		links.push split2[0]
	end	
end
links = links.uniq.sort
puts "Found: #{links.length} unique functions."

i = 0.0
functions = {}

$convert_types = {
  "float"=>"Float",
  "integer"=>"Fixnum",
  "key"=>"Key",
  "vector"=>"Vector",
  "string"=>"String",
  "rotation"=>"Rotation",
  ""=>"unknown"
}

def fix_type(dat)
  return $convert_types[dat]
end

last_time = Time.now
diff_times = []
links.each do |link_base|
	i+=1.0
	min = 0.0
	if i>1.0
		cur_time = Time.now
		diff_times.push cur_time-last_time
		diff_time = (diff_times.inject(:+).to_f / diff_times.size)*(links.length-i)
		last_time = cur_time
		min = (diff_time/60.0)
		if i>5.0
			diff_times.shift
		end
	end
	puts "#{(i/links.length.to_f*100.0).to_i}% - ETA: #{min.floor}m:#{(min-min.floor)*60.0}s - Downloading & Parsing: #{link_base}"
	url = "http://wiki.secondlife.com/w/index.php?title="+link_base.split("/")[2]+"&action=edit"
	puts "URL: #{url}"
	data = Net::HTTP.get_response(URI.parse(url)).body
	#puts data
	split = data.delete("\n").split("|")
	#puts split.length
	type = ""
	func = ""
	args = []
	experimental = false
	split.each do |bit|
		split2 = bit.split("=")
		#puts "Bit: #{bit}"
		#puts "Split2: #{split2}"
		if split2!=nil
			if split2.length==2
				name = split2[0]
				dat = split2[1]
				if name=="func"
					func = dat
				elsif name == "return_type"
					type = dat
				elsif name == "mode"
					if dat=="request"
						experimental = true
						split = []
					end
				elsif name[0]=="p"
					index = name[1].to_i-1
					if index!=-1
						#puts "Index: #{index}"
						if args[index]==nil
							args[index]=""
						end
						if name[2..6]=="_type"
							args[index]=fix_type dat
						#elsif name[2..6]=="_name"
						#	args[index]+=(dat)
						end
					end
				end
			end
		end
	end
	#func = "#{type} #{func}(#{args.join(", ")});".strip
	
	if !experimental
		functions[func]=[fix_type(type),args]
	  puts "Result: "+functions[func].to_s
	else
		puts "Function is not implemented/beta."
	end
end

ruby_file = File.join(File.dirname(__FILE__),"functions.yaml")
File.open(ruby_file, "w") do |file|
	file.print YAML::dump(functions)
end
