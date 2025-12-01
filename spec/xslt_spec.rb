require 'spec_helper'

describe "XSLT" do

  it "transforms an empty html doc into an empty docx doc" do
    html = '<html><head></head><body></body></html>'
    compare_resulting_wordml_with_expected(html, " ")
  end

  it "transforms a div into a docx block element." do
    html = '<html><head></head><body><div>Hello</div></body></html>'
    compare_resulting_wordml_with_expected(html, "<w:p> <w:r> <w:t xml:space=\"preserve\">Hello</w:t> </w:r> </w:p>")
  end

  context "transform a span" do

    it "into a docx block element if child of body." do
      html = '<html><head></head><body><span>Hello</span></body></html>'
      compare_resulting_wordml_with_expected(html, "<w:p> <w:r> <w:t xml:space=\"preserve\">Hello</w:t> </w:r> </w:p>")
    end

    it "into a docx inline element if not child of body." do
      html = '<html><head></head><body><div><span>Hello</span></div></body></html>'
      compare_resulting_wordml_with_expected(html, "<w:p> <w:r> <w:t xml:space=\"preserve\">Hello</w:t> </w:r> </w:p>")
    end

  end

  it "transforms a p into a docx block element." do
    html = '<html><head></head><body><p>Hello</p></body></html>'
    compare_resulting_wordml_with_expected(html, "<w:p> <w:r> <w:t xml:space=\"preserve\">Hello</w:t> </w:r> </w:p>")
  end

  it "Should strip out details tags" do
    html = '<html><head></head><body><div><p>Hello</p><details><summary>Title</summary><p>Second</p><details></div></body></html>'
    compare_resulting_wordml_with_expected(html, "<w:p> <w:r> <w:t xml:space=\"preserve\">Hello</w:t> </w:r> </w:p>")
  end

  it "Should transform a pre" do
     html = '<pre>Lorem ipsum </pre><pre><b>Boldie...</b> Not boldie</pre><div><div><pre>dolor sit amet <i>Italic</i></pre> <div>consectetur </div></div>adipiscing <pre>elit <a href="/linkto">link </a></pre></div><div><h1>Title</h1><pre>Pre 1</pre><pre>Pre 2</pre><pre>Pre 3</pre></div>'
     expected = '<w:p> <w:r> <w:t xml:space="preserve">Lorem ipsum </w:t> </w:r> </w:p> <w:p> <w:r> <w:rPr> <w:b/> </w:rPr> <w:t xml:space="preserve">Boldie...</w:t> </w:r> <w:r> <w:t xml:space="preserve"> Not boldie</w:t> </w:r> </w:p> <w:p> <w:r> <w:t xml:space="preserve">dolor sit amet </w:t> </w:r> <w:r> <w:rPr> <w:i/> </w:rPr> <w:t xml:space="preserve">Italic</w:t> </w:r> </w:p> <w:p> <w:r> <w:t xml:space="preserve">consectetur </w:t> </w:r> </w:p> <w:p> <w:r> <w:t xml:space="preserve">adipiscing </w:t> </w:r> </w:p> <w:p> <w:r> <w:t xml:space="preserve">elit </w:t> </w:r> <w:r> <w:t xml:space="preserve">link </w:t> </w:r> </w:p> <w:p> <w:pPr> <w:pStyle w:val="Heading1"/> </w:pPr> <w:r> <w:t xml:space="preserve">Title</w:t> </w:r> </w:p> <w:p> <w:r> <w:t xml:space="preserve">Pre 1</w:t> </w:r> </w:p> <w:p> <w:r> <w:t xml:space="preserve">Pre 2</w:t> </w:r> </w:p> <w:p> <w:r> <w:t xml:space="preserve">Pre 3</w:t> </w:r> </w:p>'
     compare_resulting_wordml_with_expected(html, expected)
  end
end
