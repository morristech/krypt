module Krypt::Base64

  module Base64Impl

    def compute_len(len, a, b)
      len -= @buf.size if @buf
      ret = a * len / b
      remainder = ret % a
      if remainder
        ret += a - remainder
      end
      ret
    end

    def compute_encode_read_len(len)
      compute_len(len, 3, 4)
    end

    def compute_decode_read_len(len)
      compute_len(len, 4, 3)
    end

    def generic_read(len, read_len)
      data = yield @io.read(read_len)
      if @buf
        data = data || ""
        data = @buf << data
      end
      return data unless len
      dlen = data.size
      remainder = dlen - len
      update_buffer(data, dlen, remainder)
      data
    end

    def generic_write(data, blk_size)
      @write = true
      data = @buf ? @buf << data : data.dup
      dlen = data.size
      remainder = dlen % blk_size
      update_buffer(data, dlen, remainder)
      @io.write(yield data) if data.size > 0
    end

    def generic_close
      if @write
        @io.write(Krypt::Base64.encode(@buf)) if @buf
      else
        raise Krypt::Base64::Base64Error.new("Remaining bytes in buffer") if @buf
      end
    end

    def update_buffer(data, dlen, remainder)
      if remainder > 0
        @buf = data.slice!(dlen - remainder, remainder)
      else
        @buf = nil
      end
    end
  end

  private_constant :Base64Impl

  # Base64-encodes any data written or read from it in the process.
  #
  class Encoder < Krypt::IOFilter
    include Base64Impl

    #
    # call-seq:
    #    in.read([len=nil]) -> String or nil
    #
    # Reads from the underlying IO and Base64-encodes the data.
    # Please see IO#read for details. Note that in-place reading into
    # a buffer is not supported.
    #
    def read(len=nil)
      read_len = len ? compute_encode_read_len(len) : nil
      generic_read(len, read_len) { |data| Krypt::Base64.encode(data) }
    end

    #
    # call-seq:
    #    out.write(string) -> Integer
    #
    # Base64-encodes +string+ and writes it to the underlying IO.
    # Please see IO#write for further details.
    #
    def write(data)
      generic_write(data, 3) { |data| Krypt::Base64.encode(data) }
    end
    alias << write

    def close
      generic_close
      super
    end

  end
  
  # Base64-decodes any data written or read from it in the process.
  #
  class Decoder < Krypt::IOFilter
    include Base64Impl

    #
    # call-seq:
    #    in.read([len=nil]) -> String or nil
    #
    # Reads from the underlying IO and Base64-decodes the data.
    # Please see IO#read for further details. Note that in-place reading into
    # a buffer is not supported.
    #
    def read(len=nil)
      read_len = len ? compute_decode_read_len(len) : nil
      generic_read(len, read_len) { |data| Krypt::Base64.decode(data) }
    end

    #
    # call-seq:
    #    out.write(string) -> Integer 
    #
    # Base64-decodes string and writes it to the underlying IO.
    # Please see IO#write for further details.
    #
    def write(data)
      generic_write(data, 4) { |data| Krypt::Base64.decode(data) }
    end
    alias << write

    def close
      generic_close
      super
    end
  end
  
end
