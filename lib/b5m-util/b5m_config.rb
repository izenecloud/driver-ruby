
class B5mConfig
  attr_reader :file, :config, :id, :name, :b5mo_name, :b5mp_name, :b5mc_name
  def initialize(file)
    @file = File.expand_path(file)
    @config = YAML.load_file(@file)["config"]
    @id = File.basename(@file, ".yml")
    @name = @id
    @name = @config['name'] unless @config['name'].nil?
    @b5mo_name = "#{name}o"
    @b5mp_name = "#{name}p"
    @b5mc_name = "#{name}c"
    Dir.chdir(File.dirname(@file)) do
      @config['path_of'].each_pair do |k,v|
        if v.is_a? Array
          v.each_with_index do |vi, i|
            v[i] = File.expand_path(vi)
          end
        else
          v = File.expand_path(v)
        end
        @config['path_of'][k] = v
      end
      strs = ['b5mo_scd', 'b5mp_scd', 'b5mc_scd']
      @config["sf1_instance"].each do |si|
        strs.each do |str|
          next if si[str].nil?
          path = si[str]
          if path.is_a? Array
            path.each_with_index do |p,i|
              path[i] = File.expand_path(p)
            end
          else
            path = [File.expand_path(path)]
          end
          si[str] = path
        end
        path = si['indicator_file']
        next if path.nil?
        si['indicator_file'] = File.expand_path(path)
      end
    end
  end

  def path_of(key)

    config['path_of'][key]
  end

  def no_bdb?
    r = false
    unless $config['nobdb'].nil?
      r = true
    end

    r
  end

  def no_comment?

    path_of('comment_scd').nil?
  end

  def sf1_instances

    config['sf1_instance']
  end

end
