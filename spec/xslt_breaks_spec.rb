require 'spec_helper'

describe "XSLT to align div, p and td tags" do

  it "transforms br tags children of document body" do
    html = <<-EOL
  <!DOCTYPE html>
  <html>
  <head></head>
  <body>
    <p>Paragraph 1</p>
    <br>
    <p>Paragraph 2</p>
    <div>Paragraph 3</div>
    <br>
    <div>Paragraph 4</div>
  </body>
  </html>
    EOL
    expected_wordml = <<-EOL
  <w:p>
    <w:r>
      <w:t xml:space="preserve">Paragraph 1</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve">Paragraph 2</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve">Paragraph 3</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve">Paragraph 4</w:t>
    </w:r>
  </w:p>
    EOL
    compare_resulting_wordml_with_expected(html, expected_wordml.strip)
  end

  it "transforms br tags inside a br or p" do
    html = <<-EOL
  <!DOCTYPE html>
  <html>
  <head></head>
  <body>
    <div>
      <br>
      <div> Lorem ipsum 1 </div>
      <br>
      <p> Lorem ipsum 2 <br> Lorem ipsum 3 </p>
      <div> Lorem ipsum 4 <br> Lorem ipsum 5 </div>
    </div>
    <div> Lorem ipsum 6 <br> Lorem ipsum 7 </div>
    <p> Lorem ipsum 6 <br> Lorem ipsum 7 </p>
    <div>
      <br>
      <p>Lorem ipsum 8</p>
      <br>
      <p>Lorem ipsum 9 <br> Lorem ipsum 10</p>
    </div>
  </body>
  </html>
    EOL
    expected_wordml = <<-EOL
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 1 </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 2 </w:t>
    </w:r>
    <w:r>
      <w:br/>
    </w:r>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 3 </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 4 </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 5 </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 6 </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 7 </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 6 </w:t>
    </w:r>
    <w:r>
      <w:br/>
    </w:r>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 7 </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve">Lorem ipsum 8</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:r/>
  </w:p>
  <w:p>
    <w:r>
      <w:t xml:space="preserve">Lorem ipsum 9 </w:t>
    </w:r>
    <w:r>
      <w:br/>
    </w:r>
    <w:r>
      <w:t xml:space="preserve"> Lorem ipsum 10</w:t>
    </w:r>
  </w:p>
    EOL
    compare_resulting_wordml_with_expected(html, expected_wordml.strip)
  end

  it "transforms br tags inside lists" do
    html = <<-EOL
  <!DOCTYPE html>
  <html>
  <head></head>
  <body>
    <ol>
      <li>Text <br> new line</li>
      <li><div>Text inside div <br> new line</div></li>
      <li><p>Text inside p <br> new line</p></li>
      <li>Some text
        <br>
        <div>Text in div</div>
      </li>
    </ol>
  </body>
  </html>
    EOL
    expected_wordml = <<-EOL
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="1"/>
      </w:numPr>
    </w:pPr>
    <w:r>
      <w:t xml:space="preserve">Text </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="0"/>
      </w:numPr>
    </w:pPr>
    <w:r/>
  </w:p>
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="0"/>
      </w:numPr>
      <w:ind w:left="720"/>
    </w:pPr>
    <w:r>
      <w:t xml:space="preserve"> new line</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="1"/>
      </w:numPr>
    </w:pPr>
    <w:r>
      <w:t xml:space="preserve">Text inside div </w:t>
    </w:r>
    <w:r>
      <w:br/>
    </w:r>
    <w:r>
      <w:t xml:space="preserve"> new line</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="1"/>
      </w:numPr>
    </w:pPr>
    <w:r>
      <w:t xml:space="preserve">Text inside p </w:t>
    </w:r>
    <w:r>
      <w:br/>
    </w:r>
    <w:r>
      <w:t xml:space="preserve"> new line</w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="1"/>
      </w:numPr>
    </w:pPr>
    <w:r>
      <w:t xml:space="preserve">Some text </w:t>
    </w:r>
  </w:p>
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="0"/>
      </w:numPr>
    </w:pPr>
    <w:r/>
  </w:p>
  <w:p>
    <w:pPr>
      <w:pStyle w:val="ListParagraph"/>
      <w:numPr>
        <w:ilvl w:val="0"/>
        <w:numId w:val="0"/>
      </w:numPr>
      <w:ind w:left="720"/>
    </w:pPr>
    <w:r>
      <w:t xml:space="preserve">Text in div</w:t>
    </w:r>
  </w:p>
    EOL
    compare_resulting_wordml_with_expected(html, expected_wordml.strip)
  end
  
  it "transforms br tags inside table cells" do
    html = <<-EOL
  <!DOCTYPE html>
  <html>
  <head></head>
  <body>
    <table>
      <tbody>
        <tr>
          <td><div>Inside a div <br> in a cell</div></td>
          <td>Inside a cell <br> no div</td>
          <td>
            <ul>
              <li>Text <br> new line</li>
              <li><div>Text inside div <br> new line</div></li>
              <li><p>Text inside p <br> new line</p></li>
            </ul>
          </td>
          <td>Some text
            <br>
            <p>Text inside p</p>
          </td>
        </tr>
      </tbody>
    </table>
  </body>
  </html>
    EOL
    expected_wordml = <<-EOL
  <w:tbl>
    <w:tblPr>
      <w:tblStyle w:val="TableGrid"/>
      <w:tblW w:w="5000" w:type="pct"/>
      <w:tblBorders>
        <w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>
      </w:tblBorders>
      <w:tblLook w:val="0600" w:firstRow="0" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="1" w:noVBand="1"/>
    </w:tblPr>
    <w:tr>
      <w:tc>
        <w:tcPr/>
        <w:p>
          <w:r>
            <w:t xml:space="preserve">Inside a div </w:t>
          </w:r>
          <w:r>
            <w:br/>
          </w:r>
          <w:r>
            <w:t xml:space="preserve"> in a cell</w:t>
          </w:r>
        </w:p>
      </w:tc>
      <w:tc>
        <w:tcPr/>
        <w:p>
          <w:r>
            <w:t xml:space="preserve">Inside a cell </w:t>
          </w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:br/>
          </w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:t xml:space="preserve"> no div</w:t>
          </w:r>
        </w:p>
      </w:tc>
      <w:tc>
        <w:tcPr/>
        <w:p>
          <w:pPr>
            <w:pStyle w:val="ListParagraph"/>
            <w:numPr>
              <w:ilvl w:val="0"/>
              <w:numId w:val="1"/>
            </w:numPr>
          </w:pPr>
          <w:r>
            <w:t xml:space="preserve">Text </w:t>
          </w:r>
        </w:p>
        <w:p>
          <w:pPr>
            <w:pStyle w:val="ListParagraph"/>
            <w:numPr>
              <w:ilvl w:val="0"/>
              <w:numId w:val="0"/>
            </w:numPr>
          </w:pPr>
          <w:r/>
        </w:p>
        <w:p>
          <w:pPr>
            <w:pStyle w:val="ListParagraph"/>
            <w:numPr>
              <w:ilvl w:val="0"/>
              <w:numId w:val="0"/>
            </w:numPr>
            <w:ind w:left="720"/>
          </w:pPr>
          <w:r>
            <w:t xml:space="preserve"> new line</w:t>
          </w:r>
        </w:p>
        <w:p>
          <w:pPr>
            <w:pStyle w:val="ListParagraph"/>
            <w:numPr>
              <w:ilvl w:val="0"/>
              <w:numId w:val="1"/>
            </w:numPr>
          </w:pPr>
          <w:r>
            <w:t xml:space="preserve">Text inside div </w:t>
          </w:r>
          <w:r>
            <w:br/>
          </w:r>
          <w:r>
            <w:t xml:space="preserve"> new line</w:t>
          </w:r>
        </w:p>
        <w:p>
          <w:pPr>
            <w:pStyle w:val="ListParagraph"/>
            <w:numPr>
              <w:ilvl w:val="0"/>
              <w:numId w:val="1"/>
            </w:numPr>
          </w:pPr>
          <w:r>
            <w:t xml:space="preserve">Text inside p </w:t>
          </w:r>
          <w:r>
            <w:br/>
          </w:r>
          <w:r>
            <w:t xml:space="preserve"> new line</w:t>
          </w:r>
        </w:p>
      </w:tc>
      <w:tc>
        <w:tcPr/>
        <w:p>
          <w:r>
            <w:t xml:space="preserve">Some text </w:t>
          </w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:br/>
          </w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:t xml:space="preserve">Text inside p</w:t>
          </w:r>
        </w:p>
      </w:tc>
    </w:tr>
  </w:tbl>
    EOL
    compare_resulting_wordml_with_expected(html, expected_wordml.strip)
  end
end
