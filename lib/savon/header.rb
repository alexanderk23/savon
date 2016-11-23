require "akami"
require "gyoku"
require "uuid"

module Savon
  class Header

    def initialize(operation_name, wsdl, globals, locals)
      @gyoku_options  = { :key_converter => globals[:convert_request_keys_to] }

      @operation_name = operation_name
      @wsdl = wsdl

      @wsse = Akami.wsse
      @wsse.env_namespace = globals[:env_namespace]

      @globals        = globals
      @locals         = locals

      @wsse_auth      = globals[:wsse_auth]
      @wsse_timestamp = globals[:wsse_timestamp]
      @wsse_sign_with = globals[:wsse_sign_with]

      @global_header  = globals[:soap_header]
      @local_header   = locals[:soap_header]

      @header = build
    end

    attr_reader :local_header, :global_header, :gyoku_options,
                :wsse, :wsse_auth, :wsse_timestamp, :wsse_sign_with

    def empty?
      @header.empty?
    end

    def to_s
      @header = build
    end

    private

    def build
      build_header + build_wsse_header + (@globals[:use_wsa] ? build_wsa_header : '')
    end

    def build_header
      header =
        if global_header.kind_of?(Hash) && local_header.kind_of?(Hash)
          global_header.merge(local_header)
        elsif local_header
          local_header
        else
          global_header
        end

      convert_to_xml(header)
    end

    def build_wsse_header
      wsse.credentials(*wsse_auth) if wsse_auth
      wsse.timestamp = wsse_timestamp if wsse_timestamp
      wsse.sign_with = wsse_sign_with if wsse_sign_with
      wsse.respond_to?(:to_xml) ? wsse.to_xml : ''
    end

    def message_id
      @message_id ||= "urn:uuid:#{UUID.new.generate}"
    end

    def wsuid_hash(part)
      { 'xmlns:wsu' => Akami::WSSE::WSU_NAMESPACE, 'wsu:Id' => @wsse.signature.part_id(part) }
    end

    def build_wsa_header
       header = {
         'wsa:Action' => @locals[:soap_action],
         'wsa:MessageID' => message_id,
         'wsa:To' => @globals[:endpoint] || @wsdl.endpoint,
         'wsa:ReplyTo' => { 'wsa:Address' => 'http://www.w3.org/2005/08/addressing/anonymous' }
       }
       if @wsse.signature
          header.merge!({
            :attributes! => {
              'wsa:Action' =>  wsuid_hash(:action),
              'wsa:MessageID' =>  wsuid_hash(:message_id),
              'wsa:To' =>  wsuid_hash(:to),
              'wsa:ReplyTo' => wsuid_hash(:reply_to)
            }
          })
       end
       convert_to_xml(header)
    end

    def convert_to_xml(hash_or_string)
      if hash_or_string.kind_of? Hash
        Gyoku.xml(hash_or_string, gyoku_options)
      else
        hash_or_string.to_s
      end
    end

  end
end
