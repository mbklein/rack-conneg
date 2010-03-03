require 'rack'
require 'rack/mime'

module Rack #:nodoc:#
  
  class Conneg
    
    VERSION = '0.1.3'
    
    def initialize(app)
      @app = app
      @ignores = []
      @opts = { 
        :accept_all_extensions => false,
        :fallback => 'text/html'
      }
      @types = []

      @app.class.module_eval {
        def negotiated_ext  ; @rack_conneg_ext  ; end #:nodoc:#
        def negotiated_type ; @rack_conneg_type ; end #:nodoc:#
        def respond_to
          wants = { '*/*' => Proc.new { raise TypeError, "No handler for #{@rack_conneg_type}" } }
          def wants.method_missing(ext, *args, &handler)
            type = ext == :other ? '*/*' : Rack::Mime::MIME_TYPES[".#{ext.to_s}"]
            self[type] = handler
          end

          yield wants

          (wants[@rack_conneg_type] || wants['*/*']).call
        end
      }
      
      if block_given?
        yield self
      end
    end
    
    def call(env)
      extension = nil
      path_info = env['PATH_INFO']
      unless @ignores.find { |ignore| ignore.match(path_info) }
        # First, check to see if there's an explicit type requested
        # via the file extension
        mime_type = Rack::Mime.mime_type(::File.extname(path_info),nil)
        if mime_type
          env['PATH_INFO'] = path_info.sub!(/(\..+?)$/,'')
          extension = $1
          if !(accept_all_extensions? || @types.include?(mime_type))
            mime_type = nil
          end
        else
          # Create an array of types out of the HTTP_ACCEPT header, sorted
          # by q value and original order
          accept_types = env['HTTP_ACCEPT'].split(/,/)
          accept_types.each_with_index { |t,i|
            (accept_type,weight) = t.split(/;/)
            weight = weight.nil? ? 1.0 : weight.split(/\=/).last.to_f
            accept_types[i] = { :type => accept_type, :weight => weight, :order => i }
          }
          accept_types.sort! { |a,b| 
            ord = b[:weight] <=> a[:weight] 
            if ord == 0
              ord = a[:order] <=> b[:order]
            end
            ord
          }
          
          # Find the first item in accept_types that matches a registered
          # content type
          accept_types.find { |t|
            re = %r{^#{Regexp.escape(t[:type].gsub(/\*/,'.+'))}$}
            @types.find { |type| re.match(type) ? mime_type = type : nil }
          }
        end
        
        mime_type ||= fallback
        @app.instance_variable_set('@rack_conneg_ext',env['rack.conneg.ext'] = extension)
        @app.instance_variable_set('@rack_conneg_type',env['rack.conneg.type'] = mime_type)
      end
      @app.call(env) unless @app.nil?
    end
    
    # Should content negotiation accept any file extention passed as part of the URI path, 
    # even if it's not one of the registered provided types?
    def accept_all_extensions?
      @opts[:accept_all_extensions] ? true : false
    end
    
    # What MIME type should be used as a fallback if negotiation fails? Defaults to 'text/html'
    # since that's what's used to deliver most error message content.
    def fallback
      find_mime_type(@opts[:fallback])
    end
    
    # Specifies a route prefix or Regexp that should be ignored by the content negotiator. Use
    # for static files or any other route that should be passed through unaltered.
    def ignore(route)
      route_re = route.kind_of?(Regexp) ? route : %r{^#{route}}
      @ignores << route_re
    end
    
    # Register one or more content types that the application offers. Can be a content type string,
    # a file extension, or a symbol (e.g., 'application/xml', '.xml', and :xml are all equivalent).
    def provide(*args)
      args.flatten.each { |type|
        mime_type = find_mime_type(type)
        @types << mime_type
      }
    end
    
    # Set a content negotiation option. Valid options are:
    # * :accept_all_extensions - true if all file extensions should be mapped to MIME types whether
    #   or not their associated types are specifically provided
    # * :fallback - a content type string, file extention, or symbol representing the MIME type to
    #   fall back on if negotiation fails
    def set(key, value)
      opt_key = key.to_sym
      if !@opts.include?(opt_key)
        raise IndexError, "Unknown option: #{key.to_s}"
      end
      @opts[opt_key] = value
    end
    
    private
    def find_mime_type(type)
      valid_types = Rack::Mime::MIME_TYPES.values
      mime_type = nil
      if type =~ %r{^[^/]+/[^/]+}
        mime_type = type
      else
        ext = type.to_s
        ext = ".#{ext}" unless ext =~ /^\./
        mime_type = Rack::Mime.mime_type(ext,nil)
      end
      unless valid_types.include?(mime_type)
        raise ValueError, "Unknown MIME type: #{mime_type}"
      end
      return mime_type
    end
  end
  
  class Request
    def negotiated_ext  ; @env['rack.conneg.ext']  ; end
    def negotiated_type ; @env['rack.conneg.type'] ; end
  end

end