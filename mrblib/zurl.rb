class Zurl
  class Error < StandardError; end

  ID = 'id'
  MORE = 'more'
  TYPE = 'type'
  KEEP_ALIVE = 'keep-alive'
  FROM = 'from'
  DELIMETER = ''
  ERROR = 'error'
  BODY = 'body'
  SPACE = ' '
  CREDITS = 'credits'
  TSTRINGS_FORMAT = "T%s"

  def initialize(client_id, basepath = 'ipc:///tmp')
    @client_id = client_id
    @push = ZMQ::Push.new("#{basepath}/zurl-in")
    @router = ZMQ::Router.new("#{basepath}/zurl-in-stream", :connect)
    @sub = ZMQ::Sub.new("#{basepath}/zurl-out", client_id)
    @req = ZMQ::Req.new("#{basepath}/zurl-req")
  end

  def request(method, uri, headers = nil, body = nil, optional_fields = {})
    req = optional_fields.merge({method: method, uri: uri})
    req[:headers] = headers if headers
    req[:body] = body if body
    @req.send(sprintf(TSTRINGS_FORMAT, req.to_tnetstring))
    resp, _ = TNetStrings.parse(@req.recv.to_str.byteslice(1..-1))
    resp
  end

  def stream(method, uri, headers = nil, body = nil, optional_fields = {})
    id = Sysrandom.buf(16)
    if block_given?
      seq = 0
      req = optional_fields.merge({from: @client_id, id: id, seq: seq, stream: true, credits: 65536, method: method, uri: uri})
      req[:headers] = headers if headers
      if body
        outcredits = 0
        pos = 0
      end
      @push.send(sprintf(TSTRINGS_FORMAT, req.to_tnetstring))
      seq += 1
      loop do
        reply = @sub.recv.to_str
        data, _ = TNetStrings.parse(reply.byteslice(reply.index(SPACE)+2..-1))
        next unless data[ID] == id
        yield data unless data[TYPE]
        break if (data[ERROR]) || (!data[TYPE] && !data[MORE])
        if data[TYPE] == KEEP_ALIVE
          req = {from: @client_id, id: id, seq: seq, type: KEEP_ALIVE}
          @router.send([data[FROM], DELIMETER, sprintf(TSTRINGS_FORMAT, req.to_tnetstring)])
          seq += 1
          next
        end
        if data[BODY]
          req = {from: @client_id, id: id, seq: seq, type: :credit, credits: 65536}
          @router.send([data[FROM], DELIMETER, sprintf(TSTRINGS_FORMAT, req.to_tnetstring)])
          seq += 1
        end
        if body
          outcredits += data[CREDITS] if data[CREDITS]
          if outcredits > 0 && pos < body.bytesize
            chunk = body.byteslice(pos..outcredits)
            req = {from: @client_id, id: id, seq: seq, body: chunk}
            pos += chunk.bytesize
            req[:more] = true if pos < body.bytesize
            @router.send([data[FROM], DELIMETER, sprintf(TSTRINGS_FORMAT, req.to_tnetstring)])
            seq += 1
            outcredits -= chunk.bytesize
          end
        end
      end
    else
      req = optional_fields.merge({from: @client_id, id: id, method: method, uri: uri})
      req[:headers] = headers if headers
      req[:body] = body if body
      @push.send(sprintf(TSTRINGS_FORMAT, req.to_tnetstring))
      self
    end
  end
end
