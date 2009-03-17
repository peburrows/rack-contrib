require 'erb'
require 'fileutils'

class CSSVariables
  File = ::File
  
  def initialize(app, options={})
    @app = app
    app_env  = defined?(RAILS_ENV) ? RAILS_ENV : 'development'
    web_root = defined?(RAILS_ROOT) ? File.join(RAILS_ROOT, 'public') : File.join(File.dirname(__FILE__), '/public')

    defaults = {:env                => app_env,
                :production         => [:production],
                :parser             => 'ERB',
                :stylesheets_path   => '/stylesheets/',
                :web_root           => web_root }
                
    @options = defaults.merge(options)
    @options[:production] = @options[:production].is_a?(Array) ? @options[:production] : [@options[:production]]
  end
  
  def call(env)
    path = env['REQUEST_PATH']
    unless path =~ /\.css$/ && path =~ /^#{@options[:stylesheets_path] || @options[:stylesheet_path]}/
      # this isn't a stylesheet that is in the directory we care about (so, it'll probably raise a 404, but whatever)
      return @app.call(env)
    end
    
    variables_file = File.join(@options[:templates], 'variables.rb')
    if File.exists?(variables_file)
      if @options[:production].include?(@options[:env])
        require variables_file
      else
        load variables_file
      end
    end
  
    template_path = path.sub(/^#{@options[:stylesheets_path] || @options[:stylesheet_path]}/, '')
    @file = File.join(@options[:templates], template_path)
  
    if File.exists?(@file)
      content = eval(@options[:parser]).send(:render, File.read(@file), binding)
      length = content.respond_to?(:bytesize) ? content.bytesize.to_s : content.size.to_s
    
      if @options[:production].include?(@options[:env].to_sym)
        # make sure the directory exists
        new_dir = File.dirname(File.join(@options[:web_root], path))
        puts "the new dir is: #{new_dir}"
        FileUtils.mkdir_p(new_dir) unless File.exists?(new_dir)
        # if we're in production, write the file to the system...
        File.open(File.join(@options[:web_root], path), 'w') do |f|
          puts "[Rack::Middleware - CssVariables] writing #{path} to the public directory"
          f.write(content)
        end
      end
    
      [200, {'Content-Type' => 'text/css', 'Content-Length' => length}, [content]]
    else
      @app.call(env)
    end
  end
  
end


# give ERB the ability to respond to ERB.render(content), because, to standardize things,
# that's how the CssVariables middleware will call the parser
module ErbRenderHack
  def render(content, _bind=binding)
    new(content, nil, '-').result(_bind)
  end
end
ERB.extend(ErbRenderHack)