require 'rubygems'
require 'yaml'

#Method for parsing the various datatypes from the ECH file
def dump_binary type, length
  case type
  when 'int'
    #Process integers, assigning appropriate profile based on length
    #such as long int, short int and tiny int.
    case length
    when 4
      value = @binary_file.read(length).unpack("l").first.to_i
    when 2
      value = @binary_file.read(length).unpack("s").first.to_i
    when 1
      value = @binary_file.read(length).unpack("U").first.to_i
    end
  #Process appropriate intergers into datetime format in the database
  when 'datetime'
    case length
    when 4
      value = @binary_file.read(length).unpack("l").first.to_i
      value = Time.at(value)
    end
  #Process strings
  when 'str'
    value = @binary_file.read(length).unpack("M").first.to_s.rstrip
  #Process individual bits that are booleans
  when 'bool'
    value = @binary_file.read(length).unpack("b8").last.to_s
  #Process that one wierd boolean that is actually an int, instead of a bit
  when 'boolint'
    value = @binary_file.read(length).unpack("U").first.to_i
    #Change the values of the field to Y/N for the varchar(1) representation of BOOLEAN
    if value == 1
      value = 'Y'
    else
      value = 'N'
    end
  end
  return value
end
  
#Mehtod that performs the conversions
def convert_binary_file filename, schema
  #Open the file to process
  @binary_file = open(filename,"rb")
  puts "File size: " + @binary_file.stat.size.to_s

  #Read header information first
  fileversion = dump_binary 'int', 4
  puts "Version " + fileversion.to_s
  filenumber = dump_binary 'int', 4
  puts "File_number " + filenumber.to_s

  bool_cnt = 0
  bytearray = nil
  @record_cnt = 0
  while @binary_file.eof == FALSE do
    puts '<====================START RECORD ' + @record_cnt.to_s + ' ====================>'
    schema["echi_records"].each do | field |
      #We handle the 'boolean' fields differently, as they are all encoded as bits in a single 8-bit byte
      if field["type"] == 'bool'
        if bool_cnt == 0
          bytearray = dump_binary field["type"], field["length"]
        end
        #Ensure we parse the bytearray and set the appropriate flags
        #We need to make sure the entire array is not nil, in order to do Y/N
        #if Nil we then set all no
        if bytearray != '00000000'
          if bytearray.slice(bool_cnt,1) == '1'
            value = 'Y'
          else
            value = 'N'
          end
        else
          value = 'N'
        end
        puts field["name"] + " { type => #{field["type"]} & length => #{field["length"]} } value => " + value.to_s
        bool_cnt += 1
        if bool_cnt == 8
          bool_cnt = 0
        end
      else
        #Process 'standard' fields
        value = dump_binary field["type"], field["length"]
        puts field["name"] + " { type => #{field["type"]} & length => #{field["length"]} } value => " + value.to_s
      end
      #echi_record[field["name"]] = value
    end
      
    #Scan past the end of line record if enabled in the configuration file
    #Comment this out if you do not need to read the 'extra byte'
    @binary_file.read(1)
    puts '<====================STOP RECORD ' + @record_cnt.to_s + ' ====================>'
    @record_cnt += 1
  end
  @binary_file.close
end

#Load the schema file
config_file = File.expand_path(File.dirname(__FILE__) + "/extended_schema.yml")
schema = YAML::load_file(config_file)

convert_binary_file(ARGV[0], schema)
puts 'Finished!'