#!/usr/bin/ruby

# vim: ai ts=2 sts=2 et sw=2 ft=ruby

require 'open-uri'
require 'nokogiri'
require 'net/http'
require 'uri'
require_relative 'Datastore.rb'

# インデックスURL
# http://moeimg.net/
#
# インデックスページURL
# http://moeimg.net/page/1 など
#
# ポストURL
# http://moeimg.net/10825.html など

class Moeimg
  include Datastore
  # 基準URL
  URL = 'http://moeimg.net/'
  MOEIMG_ID = 1
  @@debug = true
 
  def parseXml(url)
    charset = nil
    begin
      html = open(url) do |f|
        charset = f.charset
        f.read
      end
    rescue => e
      return -1
    end
    return Nokogiri::HTML.parse(html, nil, charset)
  end 

  def fetchIndex
    def post2id(postUrl)
      id = postUrl.sub(/\/$/,"").sub(/.*\//,"").to_i
    end
    published = parseXml(URL)
    return -1 if published == -1
    storedNewest    = getNewPost(MOEIMG_ID)[:postUrl]
    publishedNewest = published.xpath('//div[@class="post"]/h2[@class="title"]/a')[0].attribute('href').value
    storedNewest = "http://moeimg.net/4358.html" if storedNewest == nil
    return [] if storedNewest == publishedNewest
    posts = Array.new
    post2id( storedNewest).step(post2id( publishedNewest)).to_a.each do |post_id|
      posts << URL + post_id.to_s + ".html"
    end
    return posts
  end

  def getPost(postUrl)
    doc = parseXml(postUrl)
    return -1 if doc == -1
    title      = doc.xpath('//head/title').inner_text.sub(/[ 　]?\|?[ 　]?二次萌エロ画像ブログ$/,"").strip
    p_datetime = doc.xpath('//div[@class="blog_info"]/ul/li[@class="cal"]').inner_text.gsub(" ","").gsub(/[年月]/,"-").sub("日"," ").sub(/$/,":00")

    images = Array.new
    doc.xpath('//div[@class="post"]/div[@class="box"]/a').each do |image|
      images << image.attribute('href').value.strip
    end

    return { :url => postUrl, :title => title, :p_datetime => p_datetime, :images => images}
  end
  
  def savePost(post)
    record = { :title => post[:title], :postUrl => post[:url], :siteId => MOEIMG_ID, :p_datetime => post[:p_datetime]}
    return storePost(record)
  end

  def fetchPost(post)
    post[:images].each_with_index do |imageUrl,index|
      image_detail = saveImage(imageUrl)
      next if image_detail[:status] != 0

      status = fetchImage(image_detail[:hash])[:status]

      status = storeImage(image_detail) if status == 0

      image_detail[:number] = index
      image_detail[:image_url] = imageUrl
      status = linkPostImage( MOEIMG_ID, post, image_detail)
      next if status != 0
    end
  end
end
