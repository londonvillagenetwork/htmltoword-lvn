require 'spec_helper'
require 'securerandom'

describe Htmltoword::Document do
  describe "local_images" do
    let(:html) do
      <<-EOL
        <!DOCTYPE html>
        <html>
        <head></head>
        <body>
          <img src="https://placehold.it/50x50.png" style="width:50px;height:50px">
          <a href="http://www.example.com">
            <img src="https://placehold.it/10x10.png" style="width:10px;height:10px">
            Hello!
          </a>
          <p><img src="https://placehold.it/350x150.png" style="width:350px;height:150px"></p>
          <p><img src="https://placehold.it/400x250.jpg" style="width:400px;height:250px"></p>
          <p><img src="https://placehold.it/350x150.tiff" style="width:350px;height:150px"></p>
          <p><img src="https://placehold.it/400x250.gif" style="width:400px;height:250px"></p>
        </body>
        </html>
      EOL
    end

    # Serve the remote images without the network
    before { allow(URI).to receive(:open).and_yield(StringIO.new('image data')) }

    #in order to test if the images files are embedded correctly we have to create_and_save, then open the zip and look for them. Then ensure that we cleanup the created file.
    #There is probably a better way of doing it as this seems very performance heavy but does have the advantage of testing the create method all the way through...
    it "should only embed local images" do
      filename = SecureRandom.urlsafe_base64
      begin
        docx = Htmltoword::Document.create_and_save(html, tmp_path(filename))
        Zip::File.open(tmp_path(filename)) do |zip_file|
          # Find specific entry
          expect(zip_file.glob('word/media/*').size).to eq 6
        end
        expect(URI).to have_received(:open).with(%r{\Ahttps://placehold\.it/}, 'rb').exactly(6).times
      ensure
        File.delete(tmp_path(filename))
      end
    end
  end

  describe "embedded images" do
    let(:png) { "\x89PNG\r\n\x1a\n".b + 'rest of the image'.b }
    let(:png_data_uri) { "data:image/png;base64,#{Base64.strict_encode64(png)}" }

    before { allow(URI).to receive(:open).and_yield(StringIO.new('image data')) }

    def generate(body)
      docx = Htmltoword::Document.create("<html><body>#{body}</body></html>")
      result = nil
      Zip::File.open_buffer(StringIO.new(docx)) do |zip|
        rels = Nokogiri::XML(zip.read('word/_rels/document.xml.rels'))
        image_targets = rels.remove_namespaces!.xpath("//Relationship[contains(@Type, '/image')]/@Target").map(&:value)
        media = zip.glob('word/media/*').to_h { |entry| [entry.name.delete_prefix('word/'), zip.read(entry.name)] }
        result = { image_targets: image_targets, media: media, document: zip.read('word/document.xml') }
      end
      result
    end

    it "embeds data URI images" do
      result = generate(%(<p><img src="#{png_data_uri}" style="width:2px;height:1px"><img src="#{png_data_uri}" data-filename="logo.png" style="width:2px;height:1px"></p>))
      expect(result[:image_targets]).to eq %w[media/image1.png media/image2.png]
      expect(result[:media]).to eq('media/image1.png' => png, 'media/image2.png' => png)
      expect(result[:document].scan('<w:drawing>').size).to eq 2
      expect(URI).not_to have_received(:open)
    end

    it "points the relationships at the stored files whatever the url's extension looks like" do
      result = generate(%(<p><img src="https://example.com/a.PNG" style="width:2px;height:1px"><img src="https://example.com/b.min.jpg?v=2" style="width:2px;height:1px"></p>))
      expect(result[:image_targets]).to eq %w[media/image1.png media/image2.jpg]
      expect(result[:media].keys).to eq result[:image_targets]
    end

    it "doesn't download images without a size or with data-external" do
      result = generate(%(<p><img src="https://example.com/a.png"><img src="https://example.com/b.png" data-external="true" style="width:2px;height:1px"></p>))
      expect(result[:image_targets]).to eq %w[https://example.com/b.png]
      expect(result[:media]).to be_empty
      expect(URI).not_to have_received(:open)
    end

    it "drops local file images" do
      result = generate(%(<p><img src="/etc/passwd" style="width:2px;height:1px"><img src="file:///etc/passwd" style="width:2px;height:1px"></p>))
      expect(result[:image_targets]).to be_empty
      expect(result[:media]).to be_empty
      expect(result[:document]).not_to include('<w:drawing>')
    end
  end
end
