require 'asciidoctor-pdf' unless defined? ::Asciidoctor::Pdf

module AsciidoctorPdfExtensions
  # Override the built-in layout_toc to move colophon before front of table of contents
  # NOTE we assume that the colophon fits on a single page
  def layout_toc doc, num_levels = 2, toc_page_number = 2, num_front_matter_pages = 0
    go_to_page toc_page_number unless (page_number == toc_page_number) || scratch?
    if scratch?
      colophon = doc.find_by(context: :section) {|sect| sect.sectname == 'colophon' }
      if (colophon = colophon.first)
        doc.instance_variable_set :@colophon, colophon
        colophon.parent.blocks.delete colophon
      end
    else
      if (colophon = doc.instance_variable_get :@colophon)
        # if prepress book, consume blank page before table of contents
        go_to_page(page_number - 1) if @ppbook
        convert_section colophon
        go_to_page(page_number + 1)
      end
    end
    offset = colophon && !@ppbook ? 1 : 0
    toc_page_numbers = super doc, num_levels, (toc_page_number + offset), num_front_matter_pages
    scratch? ? ((toc_page_numbers.begin - offset)..toc_page_numbers.end) : toc_page_numbers
  end

  # force chapters to start on new page;
  # force select chapters to start on the recto (odd-numbered, right-hand) page
  def start_new_chapter chapter
    start_new_page unless at_page_top?
    if @ppbook && verso_page? && !(chapter.option? 'nonfacing')
      update_colors # prevents Ghostscript from reporting a warning when running content is written to blank page
      start_new_page
    end
  end

  def layout_chapter_title node, title, opts = {}
    sect_id = node.id
    if ["about-the-author", "readers-feedback", "acknowledgements", "dedication"].include?(sect_id)
      layout_heading title, align: :center, color: [42, 1, 83, 1], style: :normal, size: 30
    elsif sect_id == 'colophon'
      #puts 'Processing ' + node.sectname + '...'
      if node.document.attr? 'media', 'prepress'
        move_down 325
      else
        move_down 460
      end
      layout_heading title, size: @theme.base_font_size
    elsif sect_id.include? 'chapter' # chapters
      #puts 'Processing ' + sect_id + '...'
      # use Akkurat font for all custom headings
      font 'Akkurat' do
        if node.document.attr? 'media', 'prepress'
          move_down 120
        else
          move_down 180
        end
        layout_heading title, align: :right, color: [42, 1, 83, 1], style: :normal, size: 30
      end

      bounds.move_past_bottom
    else
      super # delegate to default implementation
    end
  end

  def layout_heading_custom string, opts = {}
    move_down 100
    typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme.heading_line_height), {
      inline_format: true
    }.merge(opts)
    move_up 5
    i = 0
    underline = ''
    while i < string.length do
      underline += '❤'
      i += 1
    end
    # typeset_text underline, calc_line_metrics((opts.delete :line_height) || @theme.heading_line_height), {
    #   inline_format: true, color: 'B0B0B0', size: 8, style: :italic
    # }.merge(opts)
    move_down 20
  end
end

Asciidoctor::Pdf::Converter.prepend AsciidoctorPdfExtensions
