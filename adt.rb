require 'stringio'

class ADT < Struct
  def self.members() @members end
  def self.add_member(c)
    @members ||= []
    @members << c
    @members.length - 1
  end
  def self.data(*args)  
    self.construct(args).tap do |c|
      c.const_set(:MEMBER_INDEX, add_member(c))
    end
  end
  # this lets me construct structs with no fields 
  def self.construct(args)
    # oh ruby, why you so silly...
    (args.empty?) ? self.new(nil) : self.new(*args)
  end
  def self.match(&blk)
    proc do |b|
      if b.class == self
        blk.call(*b.values)
        true
      else
        false 
      end
    end
  end
end

class Packable_ADT < ADT
  def pack() packio("") end
  def packio(f)
    f << [self.class::MEMBER_INDEX].pack("C")
    f << Marshal.dump(values)
  end
  def self.unpack(data) unpackio(StringIO.new(data)) end
  def self.unpackio(f)
    tag = f.read(1).unpack("C").first
    members[tag].construct(Marshal.load(f))
  end
end
