#!/usr/bin/env ruby
require 'ruby_parser'
require 'yaml'
$parser = RubyParser.new

#TODO: Embed

ruby_file = File.join(File.dirname(__FILE__),"functions.yaml")
File.open(ruby_file, "r") do |object|
	$functions = YAML::load(object)
	#puts $functions.to_s
end
ruby_file = File.join(File.dirname(__FILE__),"events.yaml")
File.open(ruby_file, "r") do |object|
	$events = YAML::load(object)
	#puts $functions.to_s
end

$func_alias = { 
  'puts' => 'llOwnerSay', 
  'initialize' => "state_entry"
}
$accessors = { 
  "Fixnum"=>"llList2Integer",
  "Float"=> "llList2Float",
  "String"=> "llList2String"
}
$convert_types = {
  "Float"=>"float",
  "Fixnum"=>"integer",
  "Key"=>"key",
  "Vector"=>"vector",
  "String"=>"string",
  "Rotation"=>"rotation",
  "unknown"=>""
}
def ruby2lsl_type dat
  return $convert_types[dat]
end
class String
  def multi_include? ray
    ray.each do |r|
      cluded = include? r
      if cluded
        #puts "cluded"
        return true
      end
      #puts to_s
    end
    false
  end
end
$defined = {}
def convert_sexp( sexp, metadata = { :defined => {} } )
  meta = metadata.clone # Stop upflow of variables & other meta
  lsl = ""
  if sexp[0]==:class
    type = convert_sexp( sexp[2], meta )
    if type == "State_"
      var = sexp[1].to_s.downcase
      if var=="default"
        lsl << "default\n"
      else
        lsl << "state #{var}\n"
      end
      lsl << convert_sexp( sexp[3], meta )
    else
      raise "Non-State Class!"
    end
  elsif sexp[0]==:module
    meta[:type]=:module
    meta[:func_prefix]="#{sexp[1].to_s}_"
    lsl << convert_sexp( sexp[2] , meta )
  elsif sexp[0]==:scope
    mod = (meta[:type]!=:module)
    if mod
      lsl << "{\n"
    end
    meta[:type]=nil
    lsl << convert_sexp( sexp[1], meta)
    if mod
      lsl << "}\n"
   end
  elsif sexp[0]==:defn
    func = "#{meta[:func_prefix]}#{process_alias sexp[1]}"
    tmp_meta = meta.clone
    tmp_meta[:function]=func
    dat = convert_sexp( sexp[3], tmp_meta )
    lsl << "#{dat.include?('return') ? "list " : ""}#{func}( "
    lsl << convert_sexp( sexp[2], tmp_meta )
    lsl << " )\n"
    lsl << dat
  elsif sexp[0]==:args
    args = []
    sexp[1..sexp.length].each_with_index do |arg, i|
      bits = arg.to_s.split("_")
      type = "list"
      name = arg.to_s
      func = $events[meta[:function].to_s]
      #puts meta[:function]
      if func
        type = ruby2lsl_type func[1][i]
      elsif ["key","integer","list","vector","rotation","string"].include? bits[0].downcase
        type = bits[0]
        name = bits[1..bits.length].join("_")
      end
      args << "#{type} #{name}"
    end
    lsl << args.join(", ")
  elsif sexp[0]==:block
    sexp[1..sexp.length].each do |func|
      dat = convert_sexp( func, meta )
      lsl << "#{dat}#{dat.end_with?("}\n") ? "" : ";\n"}"
    end
  elsif sexp[0]==:call
    func = ""
    if sexp[1]
      lsl << "( "
      func = convert_sexp(sexp[1])
    end
    func << process_alias(sexp[2])
    if ["state","goto"].include? func
      lsl << "if(1){ #{func[0..func.length-1]} "
      lsl << convert_sexp( sexp[3], meta ).delete("_").downcase
      lsl << "; }"
    elsif meta[:defined][func]||$defined[func]
      r_type = meta[:defined][func]
      r_type ||=$defined[func]
      type=""
      tail = ""
      if r_type=="unknown"||!r_type||r_type=="List"
        type="["
        tail = "]"
      else
        type = $accessors[r_type]
        tail=", 0"
      end
      lsl << "#{type}(#{func}#{tail})"
    elsif func=="extern_lsl"
      dat = convert_sexp( sexp[3] )
      lsl << dat[1..dat.length-2]
    else
      lsl << func
      lsl << "( "
      meta[:function]=func
      lsl << convert_sexp( sexp[3], meta )
      lsl << " )"
    end
    if sexp[1]
      lsl << " )"
    end
  elsif sexp[0]==:arglist
    args = []
    sexp[1..sexp.length].each_with_index do | s, i|
      type = ""
      if meta[:function]
        #puts meta[:function]
        func = $functions[meta[:function].to_s]
        if func
          type = "(#{ruby2lsl_type(func[1][i])})"
        end
      end
      dat = convert_sexp( s )
      args << "#{type}#{dat}"
      meta[:defined][dat]=type
    end
    lsl << args.join(", ")
  elsif sexp[0]==:str
    lsl << "\"#{sexp[1]}\""
  elsif sexp[0]==:lit
    lsl << sexp[1].to_s
  elsif sexp[0]==:dstr
    args = ["\"#{sexp[1]}\""]
    sexp[2..sexp.length].each do |s|
      dat = convert_sexp( s )
      args << "#{dat.start_with?("\"") ? "" : "(string)"}#{dat}"
    end
    lsl << args.join(" + ")
  elsif sexp[0]==:evstr
    #s(:dstr, "sdfaskdfj ", s(:evstr, s(:call, s(:lit, 5), :+, s(:arglist, s(:lit, 5)))), s(:str, " second "), s(:str, "dolfin"))
    lsl << convert_sexp( sexp[1] )
  elsif sexp[0]==:lvar
    var = sexp[1].to_s
    r_type = meta[:defined][var]
    type=""
    tail = ""
    if r_type=="unknown"||!r_type
      #type="(string)"
    else
      type = $accessors[r_type]
      tail=", 0"
    end
    lsl << "#{type}(#{var}#{tail})"
  elsif sexp[0]==:lasgn
    dat = convert_sexp(sexp[2])
    var = sexp[1].to_s
    inc = meta[:defined].include?(var)
    type = "unknown"
    begin
      type = eval(dat).class.name
    rescue Exception=>e
    end
    #puts "Vartype: #{var}, #{type}"
    lsl << "#{inc ? "" : "list "}#{var} = [#{dat}]"
    if !inc
      meta[:defined][var]=type
    end
  elsif sexp[0]==:const
    lsl << "#{sexp[1].to_s}_"
  elsif sexp[0]==:attrasgn
    dat = convert_sexp(sexp[3],meta)
    var = "#{convert_sexp(sexp[1],meta)}#{sexp[2].to_s.delete("=")}"
    inc = $defined.include?(var)
    type = "unknown"
    begin
      type = eval(dat).class.name
    rescue Exception=>e
    end
    #puts "Vartype: #{var}, #{type}"
    lsl << "#{inc ? "" : "list "}#{var} = [#{dat}]"
    if !inc
      $defined[var]=type
    end
  elsif sexp[0]==:if
    #s(:if, s(:call, s(:lit, 5), :==, s(:arglist, s(:lit, 5))), s(:call, nil, :puts, s(:arglist, s(:str, "If passes."))), nil)
    lsl << "if( "
    lsl << convert_sexp(sexp[1],meta)
    lsl << " )\n{\n"
    lsl << convert_sexp(sexp[2], meta)
    lsl << "}\n"
  elsif sexp[0]==:return
    lsl << "return (list)( #{convert_sexp(sexp[1], meta)} )"
  elsif sexp[0]==:array
    parts = []
    sexp[1..sexp.length].each do |s|
      bit = convert_sexp(s, meta)
      if (bits = bit.split("..")).length>1
        (bits[0].to_i..bits[1].to_i).each do |i|
          parts << i
        end
      else
        parts << bit
      end
    end
    lsl << parts.join(", ")
  else
    puts "Implement: #{sexp[0]}, contents: #{sexp.to_s}"
  end
  return lsl
end

def process_alias str
  tmp = str.to_s
  $func_alias.each do |k, v|
    tmp.gsub!(k,v)
  end
  return tmp
end

ARGV.each do |arg|
  path = File.absolute_path(arg)
  puts "File: #{path}"
  data = ''
  f = File.open(path, "r") 
  f.each_line do |line|
    data += line
  end
  f.close
  # Preprocessor require(*)
  index = 0
  while index = data.index("require(\"",index)
    tail = data.index("\")",index)-index-9
    file = data[index+9,tail]
    filename = file.clone
    if !filename.include? ".rb"
      filename << ".rb"
    end
    if !File.exists? filename
      raise "Require Error: Cannot find #{file}"
    end
    File.open(filename, "r") do |object|
      b = ""
      object.each_line do |line|
        b += line
      end
      require_statement = "require(\"#{file}\")"
      #puts "require statement: #{require_statement}"
	    data[require_statement]=b
    end
  end
  sexp = $parser.parse(data)
  puts "Sexp: #{sexp.to_s}"
  lsl = convert_sexp( sexp )
  #puts "Converted:"
  #puts lsl
  export_path = path[0,path.length-3]+".lsl"
  f = File.open(export_path, "w") 
  f.write(lsl)
  f.close
  puts "Written to: #{export_path}"
end
