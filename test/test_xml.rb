require "test/unit"

# for entry.edit_url
require "atom/app"

class AtomTest < Test::Unit::TestCase
  def test_text_type_text
    entry = get_entry
    
    entry.title = "Atom-drunk pirates run amok!"
    assert_equal("text", entry.title["type"])

    xml = get_elements entry
    
    assert_equal("Atom-drunk pirates run amok!", xml.elements["/entry/title"].text)
  end

  def test_text_type_html
    entry = get_entry

    entry.title = "Atom-drunk pirates<br>run amok!"
    entry.title["type"] = "html"

    xml = get_elements entry

    assert_equal("Atom-drunk pirates<br>run amok!", xml.elements["/entry/title"].text)
    assert_equal("html", xml.elements["/entry/title"].attributes["type"])
  end

  def test_text_type_xhtml
    entry = get_entry

    entry.title = "Atom-drunk pirates <em>run amok</em>!"
    entry.title["type"] = "xhtml"

    xml = get_elements entry
    
    base_check xml

    assert_equal(XHTML::NS, xml.elements["/entry/title/div"].namespace)
    assert_equal("run amok", xml.elements["/entry/title/div/em"].text)
  end

  def test_author
    entry = get_entry
    a = entry.authors.new
    
    a.name= "Brendan Taylor"
    a.uri = "http://necronomicorp.com/blog/"

    xml = get_elements entry

    assert_equal("http://necronomicorp.com/blog/", xml.elements["/entry/author/uri"].text)
    assert_equal("Brendan Taylor", xml.elements["/entry/author/name"].text)
    assert_nil(xml.elements["/entry/author/email"])
  end

  def test_tags
    entry = get_entry
    entry.tag_with "test tags"

    xml = get_elements entry

    assert_has_category(xml, "test")
    assert_has_category(xml, "tags")
  end

  def test_updated
    entry = get_entry
    entry.updated = "1970-01-01"
    entry.content = "blah"

    assert_instance_of(Time, entry.updated)

    xml = get_elements entry

    assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, xml.elements["//updated"].text, "atom:updated isn't in xsd:datetime format")

    entry.update!

    assert((Time.parse("1970-01-01") < entry.updated), "<updated/> is not updated")
  end

  def test_out_of_line
    entry = get_entry

    entry.content = "this shouldn't appear"
    entry.content["src"] = 'http://example.org/test.png'
    entry.content["type"] = "image/png"

    xml = get_elements(entry)

    assert_nil(xml.elements["/entry/content"].text)
    assert_equal("http://example.org/test.png", xml.elements["/entry/content"].attributes["src"])
    assert_equal("image/png", xml.elements["/entry/content"].attributes["type"])
  end

  def test_extensions
    entry = get_entry

    assert(entry.extensions.children.empty?)

    element = REXML::Element.new("test")
    element.add_namespace "http://purl.org/"

    entry.extensions << element

    xml = get_elements entry

    assert_equal(REXML::Element, xml.elements["/entry/test"].class)
    assert_equal("http://purl.org/", xml.elements["/entry/test"].namespace)
  end

  def test_extensive_enty_parsing
str = '<entry xmlns="http://www.w3.org/2005/Atom">
  <title>Atom draft-07 snapshot</title>
  <link rel="alternate" type="text/html"
    href="http://example.org/2005/04/02/atom"/>
  <link rel="enclosure" type="audio/mpeg" length="1337"
    href="http://example.org/audio/ph34r_my_podcast.mp3"/>
  <id>tag:example.org,2003:3.2397</id>
  <updated>2005-07-31T12:29:29Z</updated>
  <published>2003-12-13T08:29:29-04:00</published>
  <author>
    <name>Mark Pilgrim</name>
    <uri>http://example.org/</uri>
    <email>f8dy@example.com</email>
  </author>
  <contributor>
    <name>Sam Ruby</name>
  </contributor>
  <contributor>
    <name>Joe Gregorio</name>
  </contributor>
  <content type="xhtml" xml:lang="en"
    xml:base="http://diveintomark.org/">
    <div xmlns="http://www.w3.org/1999/xhtml">
      <p><i>[Update: The Atom draft is finished.]</i></p>
    </div>
  </content>
</entry>'

    entry = REXML::Document.new(str).to_atom_entry 
  
    assert_equal("Atom draft-07 snapshot", entry.title.to_s)
    assert_equal("tag:example.org,2003:3.2397", entry.id)
  
    assert_equal(Time.parse("2005-07-31T12:29:29Z"), entry.updated)
    assert_equal(Time.parse("2003-12-13T08:29:29-04:00"), entry.published)

    assert_equal(2, entry.links.length)
    assert_equal("alternate", entry.links.first["rel"])
    assert_equal("text/html", entry.links.first["type"])
    assert_equal("http://example.org/2005/04/02/atom", entry.links.first["href"])

    assert_equal("enclosure", entry.links.last["rel"])
    assert_equal("audio/mpeg", entry.links.last["type"])
    assert_equal("1337", entry.links.last["length"])
    assert_equal("http://example.org/audio/ph34r_my_podcast.mp3", entry.links.last["href"])

    assert_equal(1, entry.authors.length)
    assert_equal("Mark Pilgrim", entry.authors.first.name)
    assert_equal("http://example.org/", entry.authors.first.uri)
    assert_equal("f8dy@example.com", entry.authors.first.email)
    
    assert_equal(2, entry.contributors.length)
    assert_equal("Sam Ruby", entry.contributors.first.name)
    assert_equal("Joe Gregorio", entry.contributors.last.name)
  
    assert_equal("xhtml", entry.content["type"])
   
    assert_match("<p><i>[Update: The Atom draft is finished.]</i></p>", 
                 entry.content.to_s)
    
    assert_equal("http://diveintomark.org/", entry.content.base)
    # XXX unimplemented
#    assert_equal("en", entry.content.lang)
  end

  def test_extensive_feed_parsing
feed = <<END
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title type="text">dive into mark</title>
  <subtitle type="html">
    A &lt;em&gt;lot&lt;/em&gt; of effort
    went into making this effortless
  </subtitle>
  <updated>2005-07-31T12:29:29Z</updated>
  <id>tag:example.org,2003:3</id>
  <link rel="alternate" type="text/html"
   hreflang="en" href="http://example.org/"/>
  <link rel="self" type="application/atom+xml"
   href="http://example.org/feed.atom"/>
  <rights>Copyright (c) 2003, Mark Pilgrim</rights>
  <generator uri="http://www.example.com/" version="1.0">
    Example Toolkit
  </generator>
  <entry>
    <title>Atom draft-07 snapshot</title>
    <author>
      <name>Mark Pilgrim</name>
      <uri>http://example.org/</uri>
      <email>f8dy@example.com</email>
    </author>
    <link rel="alternate" type="text/html"
     href="http://example.org/2005/04/02/atom"/>
    <id>tag:example.org,2003:3.2397</id>
    <updated>2005-07-31T12:29:29Z</updated>
  </entry>
</feed>
END

    feed = REXML::Document.new(feed).to_atom_feed

    assert_equal("", feed.base)

    assert_equal("text", feed.title["type"])
    assert_equal("dive into mark", feed.title.to_s)

    assert_equal("html", feed.subtitle["type"])
    assert_equal("\n    A <em>lot</em> of effort\n    went into making this effortless\n  ", feed.subtitle.to_s)

    assert_equal(Time.parse("2005-07-31T12:29:29Z"), feed.updated)
    assert_equal("tag:example.org,2003:3", feed.id)

    assert_equal([], feed.authors)
    
    alt = feed.links.find { |l| l["rel"] == "alternate" }
    assert_equal("alternate", alt["rel"])
    assert_equal("text/html", alt["type"])
    assert_equal("en", alt["hreflang"])
    assert_equal("http://example.org/", alt["href"])

    assert_equal("text", feed.rights["type"])
    assert_equal("Copyright (c) 2003, Mark Pilgrim", feed.rights.to_s)

    assert_equal("\n    Example Toolkit\n  ", feed.generator)
    # XXX unimplemented
    # assert_equal("http://www.example.com/", feed.generator["uri"])
    # assert_equal("1.0", feed.generator["version"])
   
    assert_equal(1, feed.entries.length)
    assert_equal "Atom draft-07 snapshot", feed.entries.first.title.to_s
  end

  def test_relative_base
    base_url = "http://www.tbray.org/ongoing/ongoing.atom"
    doc = "<entry xmlns='http://www.w3.org/2005/Atom' xml:base='When/200x/2006/10/11/'/>"
    
    entry = REXML::Document.new(doc).to_atom_entry base_url
    assert_equal("http://www.tbray.org/ongoing/When/200x/2006/10/11/", entry.base)
  end
  
  def test_edit_url
    doc = <<END
<entry xmlns="http://www.w3.org/2005/Atom"><link rel="edit"/></entry>
END
    entry = REXML::Document.new(doc).to_atom_entry

    assert_nil(entry.edit_url)

    doc = <<END
<entry xmlns="http://www.w3.org/2005/Atom"><link rel="edit"/></entry>
END

    entry = REXML::Document.new(doc).to_atom_entry

    assert_nil(entry.edit_url)
    
    doc = <<END
<entry xmlns="http://www.w3.org/2005/Atom">
  <link rel="edit" href="http://necronomicorp.com/nil"/>
</entry>
END

    entry = REXML::Document.new(doc).to_atom_entry

    assert_equal("http://necronomicorp.com/nil", entry.edit_url)
  end


  def assert_has_category xml, term
    assert_not_nil(REXML::XPath.match(xml, "/entry/category[@term = #{term}]"))
  end

  def assert_has_content_type xml, type
    assert_equal(type, xml.elements["/entry/content"].attributes["type"])
  end

  def get_entry
    Atom::Entry.new
  end

  def get_elements entry
    xml = entry.to_xml
 
    assert_equal(entry.to_s, xml.to_atom_entry.to_s) 
    
    base_check xml
    
    xml
  end

  def base_check xml
    assert_equal("entry", xml.root.name)
    assert_equal("http://www.w3.org/2005/Atom", xml.root.namespace)
  end
end