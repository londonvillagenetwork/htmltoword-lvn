require_relative 'helpers/watermark_helper'

module Htmltoword
  class Document
    include XSLTHelper
    # 1 cm = 567 twips (Word's unit of measurement)
    CM_TO_TWIPS = 567
    DEFAULT_HEADER_FOOTER_TWIPS = 708
    DEFAULT_GUTTER_TWIPS = 0

    class << self
      include TemplatesHelper
      include Htmltoword::Helpers::WatermarkHelper
      def create(content, template_name = nil, extras = false, margins: nil, watermark: nil)
        template_name += extension if template_name && !template_name.end_with?(extension)
        document = new(template_file(template_name))
        document.replace_files(content, extras)
        docx_content = document.generate
        docx_content = apply_margins_to_docx(docx_content, margins) if margins
        docx_content = apply_watermark_to_docx(docx_content, watermark) if watermark
        docx_content
      end

      def create_and_save(content, file_path, template_name = nil, extras = false, margins: nil, watermark: nil)
        File.open(file_path, 'wb') do |out|
          out << create(content, template_name, extras, margins: margins, watermark: watermark)
        end
      end

      def create_with_content(template, content, extras = false)
        template += extension unless template.end_with?(extension)
        document = new(template_file(template))
        document.replace_files(content, extras)
        document.generate
      end

      def extension
        '.docx'
      end

      def doc_xml_file
        'word/document.xml'
      end

      def numbering_xml_file
        'word/numbering.xml'
      end

      def relations_xml_file
        'word/_rels/document.xml.rels'
      end

      def content_types_xml_file
        '[Content_Types].xml'
      end

      private

      def apply_margins_to_docx(docx_content, margins_cm)
        margin_twips = margins_cm.transform_values { |cm| (cm.to_f * CM_TO_TWIPS).to_i }
        Tempfile.create(['htmltoword_input', '.docx']) do |input_file|
          input_file.binmode
          input_file.write(docx_content)
          input_file.close

          Zip::File.open(input_file.path) do |zip|
            entry = zip.find_entry('word/document.xml')
            xml_content = entry.get_input_stream.read
            modified_xml = modify_document_xml_margins(xml_content, margin_twips)
            zip.get_output_stream(entry.name) { |out| out.write(modified_xml) }
          end

          File.binread(input_file.path)
        end
      end

      def modify_document_xml_margins(xml_content, margin_twips)
        doc = Nokogiri::XML(xml_content)
        # Namespace XML de Word (required for XPath queries).
        # Define the prefix "w:" to search for elements in the internal XML of the Word document.
        # Example: "w:sectPr" is searched for as <w:sectPr> within the word/document.xml file
        namespaces = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }

        # XPath to find <w:sectPr> nodes (Section Properties)
        # which contain the margin settings and page properties
        # according to Microsoft WordprocessingML specification
        doc.xpath('//w:sectPr', namespaces).each do |sect_pr|
          pg_mar = sect_pr.at_xpath('w:pgMar', namespaces)

          unless pg_mar
            pg_mar = Nokogiri::XML::Node.new('w:pgMar', doc)
            pg_mar.namespace = sect_pr.namespace
            sect_pr.add_child(pg_mar)
          end

          margin_sides = [:top, :right, :bottom, :left]
          margin_sides.each { |side| pg_mar["w:#{side}"] = margin_twips[side].to_s }
          pg_mar['w:header'] ||= DEFAULT_HEADER_FOOTER_TWIPS.to_s
          pg_mar['w:footer'] ||= DEFAULT_HEADER_FOOTER_TWIPS.to_s
          pg_mar['w:gutter'] ||= DEFAULT_GUTTER_TWIPS.to_s
        end

        doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      def apply_watermark_to_docx(docx_content, watermark_data)
        image = extract_watermark_image(watermark_data)
        return docx_content unless image

        Tempfile.create(['htmltoword_input', '.docx']) do |input_file|
          input_file.binmode
          input_file.write(docx_content)
          input_file.close

          Zip::File.open(input_file.path) do |zip|
            document_xml = zip.find_entry('word/document.xml')&.get_input_stream&.read
            relations_xml = zip.find_entry('word/_rels/document.xml.rels')&.get_input_stream&.read
            content_types_xml = zip.find_entry('[Content_Types].xml')&.get_input_stream&.read

            next File.binread(input_file.path) unless document_xml && relations_xml && content_types_xml

            # Target in a part relationships file is resolved relative to the part (word/header*.xml)
            # The image lives in word/media/, so the correct relative target is 'media/...'
            image_target = "media/#{image[:filename]}"
            extent = calculate_watermark_extent(document_xml, image)
            # docPr ids must be unique across the whole package, body images included
            drawing_id = max_drawing_id(zip) + 1

            document_doc = Nokogiri::XML(document_xml)
            relations_doc = Nokogiri::XML(relations_xml)
            content_types_doc = Nokogiri::XML(content_types_xml)
            existing_header_paths, sections_without_header = find_default_headers(document_doc, relations_doc)

            # Template headers are kept: the watermark is added to them instead of replacing them
            existing_header_paths.each do |header_path|
              add_watermark_to_existing_header(zip, header_path, image_target, extent, drawing_id)
              drawing_id += 1
            end

            unless sections_without_header.empty?
              header_path = 'word/header_watermark.xml'
              header_target = header_path.sub('word/', '')
              header_rel_path = 'word/_rels/header_watermark.xml.rels'

              existing_ids = relations_doc.xpath('//xmlns:Relationship').map { |node| node['Id'] }
              header_rel_id = generate_unique_relationship_id(existing_ids)

              relationship_node = Nokogiri::XML::Node.new('Relationship', relations_doc)
              relationship_node['Id'] = header_rel_id
              relationship_node['Type'] = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header'
              relationship_node['Target'] = header_target
              relations_doc.root.add_child(relationship_node)

              add_header_reference_to_sections(document_doc, sections_without_header, header_rel_id)
              zip.get_output_stream('word/_rels/document.xml.rels') { |out| out.write(relations_doc.to_xml) }

              header_xml = build_watermark_header_xml(image_rel_id: 'rId1', extent: extent, drawing_id: drawing_id)
              header_rels_xml = build_header_relationships_xml(image_rel_id: 'rId1', image_target: image_target)
              zip.get_output_stream(header_path) { |out| out.write(header_xml) }
              zip.get_output_stream(header_rel_path) { |out| out.write(header_rels_xml) }
              ensure_header_content_type(content_types_doc, header_path)
            end

            zip.get_output_stream('word/document.xml') do |out|
              out.write(document_doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML))
            end
            zip.get_output_stream("word/#{image_target}") { |out| out.write(image[:data]) }

            ensure_image_content_type(content_types_doc, image[:extension])
            zip.get_output_stream('[Content_Types].xml') { |out| out.write(content_types_doc.to_xml) }
          end

          File.binread(input_file.path)
        end
      end

      # Returns the header parts already used as default headers, and the sections that need the
      # watermark header. A section without a default headerReference inherits the previous
      # section's header, so only sections before the first one with a default header need ours.
      def find_default_headers(document_doc, relations_doc)
        namespaces = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                       'r' => 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' }
        header_paths = []
        sections_without_header = []
        inherits_header = false

        document_doc.xpath('//w:sectPr', namespaces).each do |sect_pr|
          reference = sect_pr.at_xpath("w:headerReference[@w:type='default']", namespaces)
          target = reference && relations_doc.at_xpath("//xmlns:Relationship[@Id='#{reference['r:id']}']")&.[]('Target')
          # A reference whose relationship is missing would leave two default headers once ours is added
          reference.remove if reference && !target

          if target
            inherits_header = true
            header_paths << (target.start_with?('/') ? target.delete_prefix('/') : "word/#{target}")
          elsif !inherits_header
            sections_without_header << sect_pr
          end
        end

        [header_paths.uniq, sections_without_header]
      end

      def max_drawing_id(zip)
        zip.glob('word/**/*.xml').flat_map do |entry|
          entry.get_input_stream.read.scan(/<\w+:docPr\b[^>]*?\sid="(\d+)"/).flatten.map(&:to_i)
        end.max.to_i
      end

      def add_watermark_to_existing_header(zip, header_path, image_target, extent, drawing_id)
        header_entry = zip.find_entry(header_path)
        return unless header_entry

        header_doc = Nokogiri::XML(header_entry.get_input_stream.read)
        rels_path = "#{File.dirname(header_path)}/_rels/#{File.basename(header_path)}.rels"
        rels_entry = zip.find_entry(rels_path)

        if rels_entry
          rels_doc = Nokogiri::XML(rels_entry.get_input_stream.read)
          existing_ids = rels_doc.xpath('//xmlns:Relationship').map { |node| node['Id'] }
          image_rel_id = generate_unique_relationship_id(existing_ids)
          relationship_node = Nokogiri::XML::Node.new('Relationship', rels_doc)
          relationship_node['Id'] = image_rel_id
          relationship_node['Type'] = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image'
          relationship_node['Target'] = image_target
          rels_doc.root.add_child(relationship_node)
          rels_xml = rels_doc.to_xml
        else
          image_rel_id = 'rId1'
          rels_xml = build_header_relationships_xml(image_rel_id: image_rel_id, image_target: image_target)
        end

        WATERMARK_NAMESPACES.each do |attribute, href|
          prefix = attribute.delete_prefix('xmlns:')
          header_doc.root.add_namespace_definition(prefix, href) unless header_doc.root.namespaces[attribute]
        end

        namespaces = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }
        watermark_doc = Nokogiri::XML(build_watermark_header_xml(image_rel_id: image_rel_id, extent: extent,
                                                                 drawing_id: drawing_id))
        watermark_run = watermark_doc.at_xpath('/w:hdr/w:p/w:r', namespaces)

        # Put the anchored drawing in the header's first top-level paragraph so the header's
        # height is unchanged; it is positioned relative to the page, not the paragraph
        if (paragraph = header_doc.root.at_xpath('w:p', namespaces))
          if (paragraph_properties = paragraph.at_xpath('w:pPr', namespaces))
            paragraph_properties.add_next_sibling(watermark_run)
          elsif paragraph.element_children.first
            paragraph.element_children.first.add_previous_sibling(watermark_run)
          else
            paragraph.add_child(watermark_run)
          end
        else
          header_doc.root.add_child(watermark_run.parent)
        end

        zip.get_output_stream(header_path) do |out|
          out.write(header_doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML))
        end
        zip.get_output_stream(rels_path) { |out| out.write(rels_xml) }
      end

      def generate_unique_relationship_id(existing_ids)
        index = existing_ids.filter_map do |id|
          id.to_s.sub(/^rId/, '')
             .then { |num| Integer(num, exception: false) }
        end.max.to_i + 1

        loop do
          candidate = "rId#{index}"
          return candidate unless existing_ids.include?(candidate)
          index += 1
        end
      end

      def add_header_reference_to_sections(document_doc, sections, header_rel_id)
        unless document_doc.root.namespaces.value?('http://schemas.openxmlformats.org/officeDocument/2006/relationships')
          document_doc.root.add_namespace_definition('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
        end

        sections.each do |sect_pr|
          header_reference = Nokogiri::XML::Node.new('w:headerReference', document_doc)
          header_reference['w:type'] = 'default'
          header_reference['r:id'] = header_rel_id
          # CT_SectPr requires headerReference/footerReference before any other child (pgSz, pgMar, ...)
          if (first_child = sect_pr.element_children.first)
            first_child.add_previous_sibling(header_reference)
          else
            sect_pr.add_child(header_reference)
          end
        end
      end


      def ensure_header_content_type(content_types_doc, header_path)
        part_name = "/#{header_path}"
        return if content_types_doc.at_xpath("//xmlns:Override[@PartName='#{part_name}']")

        override_node = Nokogiri::XML::Node.new('Override', content_types_doc)
        override_node['PartName'] = part_name
        override_node['ContentType'] = 'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml'
        content_types_doc.root.add_child(override_node)
      end

      def ensure_image_content_type(content_types_doc, extension)
        ext = extension == 'jpeg' ? 'jpg' : extension
        return if content_types_doc.at_xpath("//xmlns:Default[@Extension='#{ext}']")

        default_node = Nokogiri::XML::Node.new('Default', content_types_doc)
        default_node['Extension'] = ext
        default_node['ContentType'] = "image/#{extension}"
        content_types_doc.root.add_child(default_node)
      end
    end

    def initialize(template_path)
      @replaceable_files = {}
      @template_path = template_path
      @image_files = []
    end

    #
    # Generate a string representing the contents of a docx file.
    #
    def generate
      Zip::File.open(@template_path) do |template_zip|
        relations_xml, template_relation_ids = merge_template_relations(template_zip)
        buffer = Zip::OutputStream.write_buffer do |out|
          template_zip.each do |entry|
            out.put_next_entry entry.name
            if @replaceable_files[entry.name] && entry.name == Document.doc_xml_file
              source = rename_relationship_ids(entry.get_input_stream.read, template_relation_ids)
              # Change only the body of document. TODO: Improve this...
              source = source.sub(/(<w:body>)((.|\n)*?)(<w:sectPr)/, "\\1#{@replaceable_files[entry.name]}\\4")
              out.write(source)
            elsif @replaceable_files[entry.name] && entry.name == Document.relations_xml_file
              out.write(relations_xml)
            elsif @replaceable_files[entry.name]
              out.write(@replaceable_files[entry.name])
            elsif entry.name == Document.content_types_xml_file
              raw_file = entry.get_input_stream.read
              content_types = @image_files.empty? ? raw_file : inject_image_content_types(raw_file)

              out.write(content_types)
            else
              out.write(template_zip.read(entry.name))
            end
          end
          unless @image_files.empty?
            # stream the image files into the media folder
            @image_files.each do |hash|
              out.put_next_entry("word/media/#{hash[:filename]}")
              if hash[:data]
                out.write(hash[:data])
              else
                URI.open(hash[:url], 'rb') do |f|
                  out.write(f.read)
                end
              end
            end
          end
        end
        buffer.string
      end
    end

    def replace_files(html, extras = false)
      html = '<body></body>' if html.nil? || html.empty?
      original_source = Nokogiri::HTML(html.gsub(/>\s+</, '><'))
      source = xslt(stylesheet_name: 'cleanup').transform(original_source)
      transform_and_replace(source, xslt_path('numbering'), Document.numbering_xml_file)
      transform_and_replace(source, xslt_path('relations'), Document.relations_xml_file)
      transform_doc_xml(source, extras)
      local_images(source)
    end

    def transform_doc_xml(source, extras = false)
      transformed_source = xslt(stylesheet_name: 'cleanup').transform(source)
      transformed_source = xslt(stylesheet_name: 'inline_elements').transform(transformed_source)
      transform_and_replace(transformed_source, document_xslt(extras), Document.doc_xml_file, extras)
    end

    private

    def transform_and_replace(source, stylesheet_path, file, remove_ns = false)
      stylesheet = xslt(stylesheet_path: stylesheet_path)
      content = stylesheet.apply_to(source)
      content.gsub!(/\s*xmlns:(\w+)="(.*?)\s*"/, '') if remove_ns
      @replaceable_files[file] = content
    end

    #generates an array of hashes with filename and full url
    #for all images to be embeded in the word document
    def local_images(source)
      source.css('img').each_with_index do |image, i|
        src = image['src'].to_s
        next if src.empty?

        data_image = parse_data_image(src)
        # Same as ActiveSupport's presence: blank (nil, empty or whitespace) becomes nil
        provided_filename = image['data-filename'] unless image['data-filename'].to_s.strip.empty?

        if data_image
          ext = data_image[:ext]
          filename = sanitize_filename(provided_filename || "image#{i + 1}.#{ext}")
          @image_files << { filename: filename, data: data_image[:data], ext: ext }
        else
          # Remote/absolute URL (or relative); derive extension from filename if present
          inferred_filename = provided_filename || src.split('/').last.to_s
          ext = File.extname(inferred_filename).delete('.').downcase
          # fallback if no extension could be inferred
          ext = 'png' if ext.empty?
          filename = sanitize_filename("image#{i + 1}.#{ext}")
          @image_files << { filename: filename, url: src, ext: ext }
        end
      end
    end

    def parse_data_image(src)
      # Supports data URI images: data:image/<type>;base64,<payload>
      m = src.match(%r{\Adata:(image/[^;]+);base64,(.+)\z}m)
      return nil unless m

      mime = m[1]
      b64 = m[2]
      ext = case mime
            when 'image/jpeg', 'image/jpg' then 'jpg'
            when 'image/png' then 'png'
            else nil
            end
      return nil unless ext

      { data: Base64.decode64(b64), ext: ext }
    rescue ArgumentError
      nil
    end

    def sanitize_filename(name)
      # Minimal sanitization to avoid invalid zip entry names
      name.gsub(/[\\\:\\*\?\"\<\>\|]/, '_')
    end

    #get extension from filename and clean to match content_types
    def content_type_from_extension(ext)
      ext == "jpg" ? "jpeg" : ext
    end

    #inject the required content_types into the [content_types].xml file...
    # relations.xslt rebuilds document.xml.rels from scratch, so the relationships the template's own
    # parts rely on (headers, footers, footnotes, ...) are copied over. They are renumbered after the
    # generated ones, which start at rId8 and would otherwise clash. Hyperlinks and images belong to the
    # template body, which is replaced, so they are dropped.
    TEMPLATE_BODY_RELATIONSHIP_TYPES = %w[hyperlink image].map do |type|
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/#{type}"
    end.freeze

    def merge_template_relations(template_zip)
      generated_xml = @replaceable_files[Document.relations_xml_file]
      template_entry = template_zip.find_entry(Document.relations_xml_file)
      return [generated_xml, {}] unless generated_xml && template_entry

      generated_doc = Nokogiri::XML(generated_xml)
      generated = generated_doc.xpath('//xmlns:Relationship')
      existing = generated.map { |node| [node['Type'], node['Target']] }
      next_id = generated.filter_map { |node| node['Id'][/\ArId(\d+)\z/, 1]&.to_i }.max.to_i + 1
      ids = {}

      Nokogiri::XML(template_entry.get_input_stream.read).xpath('//xmlns:Relationship').each do |node|
        next if TEMPLATE_BODY_RELATIONSHIP_TYPES.include?(node['Type'])
        next if existing.include?([node['Type'], node['Target']])

        ids[node['Id']] = "rId#{next_id}"
        next_id += 1
        node['Id'] = ids[node['Id']]
        generated_doc.root.add_child(node)
      end

      return [generated_xml, ids] if ids.empty?

      [generated_doc.to_xml, ids]
    end

    # Applied to the template's document.xml before its body is replaced, so only the template's own
    # references (e.g. headerReference/footerReference in sectPr) are renamed
    def rename_relationship_ids(source, ids)
      return source if ids.empty?

      source.gsub(/(\sr:\w+=")([^"]*)(")/) { "#{$1}#{ids.fetch($2, $2)}#{$3}" }
    end

    def inject_image_content_types(source)
      doc = Nokogiri::XML(source)

      #get a list of all extensions currently in content_types file
      existing_exts = doc.css("Default").map { |node| node.attribute("Extension").value }.compact

      #get a list of extensions we need for our images
      required_exts = @image_files.map{ |i| i[:ext] }

      #workout which required extensions are missing from the content_types file
      missing_exts = (required_exts - existing_exts).uniq

      #inject missing extensions into document
      missing_exts.each do |ext|
        doc.at_css("Types").add_child( "<Default Extension='#{ext}' ContentType='image/#{content_type_from_extension(ext)}'/>")
      end

      #return the amended source to be saved into the zip
      doc.to_s
    end
  end
end
