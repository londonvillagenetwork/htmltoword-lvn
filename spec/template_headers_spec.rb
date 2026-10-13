require 'spec_helper'
require 'base64'
require 'securerandom'

describe Htmltoword::Document do
  W_NS = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }.freeze
  HEADER_TYPE = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header'.freeze

  # 2x1 PNG
  let(:png) do
    ['89504E470D0A1A0A0000000D4948445200000002000000010802000000' \
     '7B40E85D0000000F49444154789C63F8CFC0F09F01000502FE02B1CB6EAB0000000049454E44AE426082'].pack('H*')
  end
  let(:png_data_uri) { "data:image/png;base64,#{Base64.strict_encode64(png)}" }

  let(:template_name) { SecureRandom.urlsafe_base64 }
  let(:templates_dir) { File.dirname(tmp_path(template_name)) }

  # The default template plus a default header with its own relationships file
  def build_template_with_header
    Zip::File.open(template_file(nil)) do |source|
      Zip::OutputStream.open(tmp_path(template_name)) do |out|
        source.each do |entry|
          content = source.read(entry.name)
          case entry.name
          when 'word/document.xml'
            content = content.sub(/<w:sectPr([^>]*)>/,
                                  '<w:sectPr\1><w:headerReference w:type="default" r:id="rId99"/>')
          when 'word/_rels/document.xml.rels'
            content = content.sub('</Relationships>',
                                  %(<Relationship Id="rId99" Type="#{HEADER_TYPE}" Target="header1.xml"/></Relationships>))
          when '[Content_Types].xml'
            content = content.sub('</Types>', '<Override PartName="/word/header1.xml" ' \
                                              'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/></Types>')
          end
          out.put_next_entry(entry.name)
          out.write(content)
        end

        out.put_next_entry('word/header1.xml')
        out.write('<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' \
                  'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">' \
                  '<w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>Template header</w:t></w:r>' \
                  '<w:r><w:drawing><wp:inline><wp:docPr id="5" name="Logo"/></wp:inline></w:drawing></w:r></w:p></w:hdr>')
        out.put_next_entry('word/_rels/header1.xml.rels')
        out.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' \
                  '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" ' \
                  'Target="https://example.com" TargetMode="External"/></Relationships>')
      end
    end
  end

  # Body images must be http(s) URLs (cleanup.xslt drops the rest); serve them without the network
  before { allow(URI).to receive(:open).and_yield(StringIO.new(png)) }

  def read_docx(docx)
    files = {}
    Zip::File.open_buffer(docx) { |zip| zip.each { |entry| files[entry.name] = zip.read(entry.name) unless entry.directory? } }
    files
  end

  def default_header_ids(document_xml)
    Nokogiri::XML(document_xml).xpath("//w:sectPr/w:headerReference[@w:type='default']", W_NS).map { |node| node['r:id'] }
  end

  def docpr_ids(files)
    files.select { |name, _| name.end_with?('.xml') }.values.flat_map { |xml| xml.scan(/<wp:docPr\b[^>]*?\sid="(\d+)"/).flatten }
  end

  def relationship_target(rels_xml, id)
    Nokogiri::XML(rels_xml).at_xpath("//xmlns:Relationship[@Id='#{id}']")&.[]('Target')
  end

  context 'with a template that has a header' do
    before do
      build_template_with_header
      @custom_templates_path = Htmltoword.config.custom_templates_path
      Htmltoword.config.custom_templates_path = templates_dir
    end

    after do
      Htmltoword.config.custom_templates_path = @custom_templates_path
      File.delete(tmp_path(template_name)) if File.exist?(tmp_path(template_name))
    end

    it 'keeps the header relationship, renumbered after the generated ones' do
      files = read_docx(described_class.create('<p><a href="https://example.org">link</a></p>', template_name))

      ids = default_header_ids(files['word/document.xml'])
      expect(ids).to eq(['rId9'])
      expect(relationship_target(files['word/_rels/document.xml.rels'], 'rId9')).to eq('header1.xml')
      expect(relationship_target(files['word/_rels/document.xml.rels'], 'rId8')).to eq('https://example.org')
    end

    it 'adds the watermark to the template header instead of adding a second header' do
      files = read_docx(described_class.create('<p>Hi</p>', template_name, watermark: png_data_uri))

      ids = default_header_ids(files['word/document.xml'])
      expect(ids.size).to eq(1)
      expect(relationship_target(files['word/_rels/document.xml.rels'], ids.first)).to eq('header1.xml')
      expect(files).not_to have_key('word/header_watermark.xml')

      header = Nokogiri::XML(files['word/header1.xml'])
      expect(header.text).to include('Template header')
      blip_id = header.at_xpath('//a:blip', 'a' => 'http://schemas.openxmlformats.org/drawingml/2006/main')['r:embed']
      expect(blip_id).not_to eq('rId1')
      expect(relationship_target(files['word/_rels/header1.xml.rels'], blip_id)).to eq('media/watermark.png')
      expect(relationship_target(files['word/_rels/header1.xml.rels'], 'rId1')).to eq('https://example.com')
    end

    it 'gives the watermark a drawing id not used by the template header or body images' do
      html = '<p><img src="https://example.com/a.png" style="width:20px;height:10px"><img src="https://example.com/b.png" style="width:20px;height:10px"></p>'
      ids = docpr_ids(read_docx(described_class.create(html, template_name, watermark: png_data_uri)))

      expect(ids.size).to eq(4)
      expect(ids).to eq(ids.uniq)
    end
  end

  context 'with the default template' do
    it 'adds one watermark header, referenced first in sectPr' do
      files = read_docx(described_class.create('<p>Hi</p>', watermark: png_data_uri))

      sect_pr = Nokogiri::XML(files['word/document.xml']).at_xpath('//w:body/w:sectPr', W_NS)
      first = sect_pr.element_children.first
      expect(first.name).to eq('headerReference')
      expect(default_header_ids(files['word/document.xml']).size).to eq(1)
      expect(relationship_target(files['word/_rels/document.xml.rels'], first['r:id'])).to eq('header_watermark.xml')
      expect(files['word/media/watermark.png']).to eq(png.b)
    end

    it 'gives the watermark a drawing id not used by body images' do
      html = '<p><img src="https://example.com/a.png" style="width:20px;height:10px"><img src="https://example.com/b.png" style="width:20px;height:10px"></p>'
      ids = docpr_ids(read_docx(described_class.create(html, watermark: png_data_uri)))

      expect(ids.size).to eq(3)
      expect(ids).to eq(ids.uniq)
    end

    it 'accepts plain base64 without a data URI prefix' do
      files = read_docx(described_class.create('<p>Hi</p>', watermark: Base64.strict_encode64(png)))

      expect(files).to have_key('word/header_watermark.xml')
      expect(files).to have_key('word/media/watermark.png')
    end
  end

  describe '.extract_watermark_image' do
    it 'reads the image dimensions' do
      expect(described_class.extract_watermark_image(png_data_uri)[:dimensions]).to eq([2, 1])
    end

    it 'ignores unsupported formats' do
      expect(described_class.extract_watermark_image(Base64.strict_encode64('GIF89a'))).to be_nil
    end
  end
end
