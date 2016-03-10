class OptionsParser
  BINARY_VERSION_WITHOUT_DASHES = Gem::Version.new('0.12.0')

  def initialize(options, binary_version)
    @options = options
    @binary_version = binary_version
  end

  attr_reader :options, :binary_version

  def parse_extra
    return [] if options[:extra].nil?
    return options[:extra].split if options[:extra].respond_to?(:split)
    options[:extra]
  end

  def parse_others
    r = []
    unless options.blank?
      r += make_options(options, [:proxy,
                                  :username,
                                  :password,
                                  :encoding,
                                  :user_style_sheet,
                                  :viewport_size])
      r += make_options(options, [:cookie,
                                  :post], '', :name_value)
      r += make_options(options, [:redirect_delay,
                                  :zoom,
                                  :page_offset,
                                  :javascript_delay], '', :numeric)
      r += make_options(options, [:book,
                                  :default_header,
                                  :disable_javascript,
                                  :enable_plugins,
                                  :disable_internal_links,
                                  :disable_external_links,
                                  :print_media_type,
                                  :disable_smart_shrinking,
                                  :use_xserver,
                                  :no_background], '', :boolean)
      r += make_options(options, [:no_stop_slow_scripts], '', nil)
    end
    r
  end

  def parse_global
    r = []
    unless options.blank?
      r += make_options(options, [:orientation,
                                  :dpi,
                                  :page_size,
                                  :page_width,
                                  :title])
      r += make_options(options, [:lowquality,
                                  :grayscale,
                                  :no_pdf_compression], '', :boolean)
      r += make_options(options, [:image_dpi,
                                  :image_quality,
                                  :page_height], '', :numeric)
      r += parse_margins(options.delete(:margin))
    end
    r
  end

  def parse_outline
    outline = options.delete(:outline)
    r = []
    unless outline.blank?
      r = make_options(outline, [:outline], '', :boolean)
      r += make_options(outline, [:outline_depth], '', :numeric)
    end
    r
  end

  def parse_header_footer
    args = {
      :header => options.delete(:header),
      :footer => options.delete(:footer),
      :layout => options[:layout]
    }
    r = []
    [:header, :footer].collect do |hf|
      next if args[hf].blank?
      opt_hf = args[hf]
      r += make_options(opt_hf, [:center, :font_name, :left, :right], "#{hf}")
      r += make_options(opt_hf, [:font_size, :spacing], "#{hf}", :numeric)
      r += make_options(opt_hf, [:line], "#{hf}", :boolean)
      if args[hf] && args[hf][:content]
        @hf_tempfiles = [] unless defined?(@hf_tempfiles)
        @hf_tempfiles.push(tf = WickedPdfTempfile.new("wicked_#{hf}_pdf.html"))
        tf.write args[hf][:content]
        tf.flush
        args[hf][:html] = {}
        args[hf][:html][:url] = "file:///#{tf.path}"
      end
      unless opt_hf[:html].blank?
        r += make_option("#{hf}-html", opt_hf[:html][:url]) unless opt_hf[:html][:url].blank?
      end
    end unless args.blank?
    r
  end

  def parse_cover
    cover = options.delete(:cover)
    arg = cover.to_s
    return [] if arg.blank?

    # Filesystem path or URL - hand off to wkhtmltopdf
    if cover.is_a?(Pathname) || (arg[0, 4] == 'http')
      [valid_option('cover'), arg]
    else # HTML content
      @hf_tempfiles ||= []
      @hf_tempfiles << tf = WickedPdfTempfile.new('wicked_cover_pdf.html')
      tf.write arg
      tf.flush
      [valid_option('cover'), tf.path]
    end
  end

  def parse_toc
    toc = options.delete(:toc)
    return [] if toc.nil?
    r = [valid_option('toc')]
    unless toc.blank?
      r += make_options(toc, [:font_name, :header_text], 'toc')
      r += make_options(toc, [:xsl_style_sheet])
      r += make_options(toc, [:depth,
                                  :header_fs,
                                  :text_size_shrink,
                                  :l1_font_size,
                                  :l2_font_size,
                                  :l3_font_size,
                                  :l4_font_size,
                                  :l5_font_size,
                                  :l6_font_size,
                                  :l7_font_size,
                                  :level_indentation,
                                  :l1_indentation,
                                  :l2_indentation,
                                  :l3_indentation,
                                  :l4_indentation,
                                  :l5_indentation,
                                  :l6_indentation,
                                  :l7_indentation], 'toc', :numeric)
      r += make_options(toc, [:no_dots,
                                  :disable_links,
                                  :disable_back_links], 'toc', :boolean)
      r += make_options(toc, [:disable_dotted_lines,
                                  :disable_toc_links], nil, :boolean)
    end
    r
  end

  def parse_basic_auth
    if options[:basic_auth]
      user, passwd = Base64.decode64(options[:basic_auth]).split(':')
      ['--username', user, '--password', passwd]
    else
      []
    end
  end

  private

  def valid_option(name)
    if binary_version < BINARY_VERSION_WITHOUT_DASHES
      "--#{name}"
    else
      name
    end
  end

  def parse_margins(opts)
    make_options(opts, [:top, :bottom, :left, :right], 'margin', :numeric)
  end

  def make_options(options, names, prefix = '', type = :string)
    return [] if options.nil?
    names.collect do |o|
      if options[o].blank?
        []
      else
        make_option("#{prefix.blank? ? '' : prefix + '-'}#{o}",
                    options[o],
                    type)
      end
    end
  end


  def make_option(name, value, type = :string)
    if value.is_a?(Array)
      return value.collect { |v| make_option(name, v, type) }
    end
    if type == :name_value
      parts = value.to_s.split(' ')
      ["--#{name.tr('_', '-')}", *parts]
    elsif type == :boolean
      ["--#{name.tr('_', '-')}"]
    else
      ["--#{name.tr('_', '-')}", value.to_s]
    end
  end
end
