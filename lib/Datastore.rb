# vim: ai ts=2 sts=2 et sw=2 ft=ruby

require 'mysql2'
require 'open-uri'
require 'digest'

module Datastore
  @@client = Mysql2::Client.new(:host => '127.0.0.1', :port => 3306, :username => 'root', :password => 'database', :database => 'database')
  @@digest = Digest::SHA1.new
  
  # SQLを実行して返すだけ
  def selectSql (query)
    result = Array.new
    row_result = Hash.new
    
    raw_result = @@client.query( query)

    raw_result.each do |row|
      row.each do |key,value|
        row_result[ key.to_sym] = value
      end
      result << row_result
    end

    return result
  end

  # URLの画像をダウンロードしてファイルに保存
  def saveImage(url)
    error = false
    # 作業ディレクトリ作成
    Dir.mkdir("tmp/") if !Dir.exists?("tmp/")
    # ファイル保存
    dest = "tmp/" + File.basename(url)
    hash = ""
    open(dest, "wb") do |file|
      begin
        open(url) do |source|
          file.write(source.read)
          hash = (Digest::SHA1.file(dest)).hexdigest
          dirlv1 = "tmp/" + hash[0] + hash[1]
          dirlv2 = dirlv1 + "/" + hash[2] + hash[3]
          Dir.mkdir( dirlv1) if !Dir.exists?( dirlv1)
          Dir.mkdir( dirlv2) if !Dir.exists?( dirlv2)
          File.rename( dest, dirlv2 + "/" + hash + File.extname(dest)) if !File.exists?( dirlv2 + hash + File.extname(dest))
        end
      rescue => e
        print "Image " + url + " ... " 
        puts e
        error = true
      end
    end
    File.delete(dest) if error == true
    
    return { :status => 2, :file => nil, :hash => nil} if error == true
    return { :status => 0, :file => "tmp/" + hash + File.extname(dest), :hash => hash}
  end

  def fetchImage(hash)
    # DBへ登録 DBのレコードからファイル名は察してほしい設計
    record = selectSql(%q{SELECT * FROM image WHERE hash = '} + hash + %q{'})
    if record.length == 0 then
      return { :status => 0, :file => nil, :hash => hash}
    else
      filepath = hash
      return { :status => 1, :file => filepath, :hash => hash}
    end
  end

  def storeImage (imageFile)
    p imageFile
    @@client.query(%q{INSERT INTO image ( hash, r_date) VALUES ( '} + imageFile[:hash] + %q{', NOW())})
    return { :status => 0, :file => imageFile[:file], :hash => imageFile[:hash]}
  end

  def findImage (url)
    result = selectSql(%q{SELECT * FROM sitepost WHERE url = '} + url + %q{'})
    return { :status => nil, :hash => nil, :file => nil} if result.length == 0
    
    hash = result[0][:image]
    filepath = "TODO 未実装"
    return { :status => 0, :hash => hash, :file => filepath}
  end

  def storePost (post)
    result = selectSql(%q{SELECT * FROM post WHERE url = '} + post[:postUrl] + %q{'})
    return -1 if result.length != 0
    @@client.query(%q{INSERT INTO post ( title, url, site_id, p_datetime, r_datetime) VALUES ( '} + post[:title] + %q{','} + post[:postUrl] + %q{',} + post[:siteId].to_s + %q{, '} + post[:p_datetime] + %q{', NOW())})
    return 0
  end

  def linkPostImage ( site_id, post, imageDetail)
    image_title = imageDetail[:image_url].gsub(/.*\//,"")
    result = selectSql(%q{SELECT * FROM sitepost WHERE url = '} + post[:url] + %q{' AND image_title = '} + image_title + %q{'})
    return 1 if result.length != 0

    @@client.query(%q{INSERT INTO sitepost ( title, url, site_id, number, image_title, image, r_datetime) VALUES ( '} + post[:title] + %q{','} + post[:url] + %q{',} + site_id.to_s + %q{, '} + imageDetail[:number].to_s + %q{', '} + image_title + %q{', '} + imageDetail[:hash] + %q{', NOW())})
    return 0
  end

  def getNewPost (site_id)
    result = selectSql(%q{SELECT * FROM post WHERE site_id = } + site_id.to_s + %q{ ORDER BY id DESC LIMIT 1})
    return ({ :status => 0, :title => result[0][:title], :postUrl => result[0][:url], :siteId => site_id}) if result.length != 0
    return ({ :status => 1, :title => nil, :postUrl => nil, :siteId => site_id}) if result.length == 0
  end

  module_function :saveImage, :fetchImage, :storeImage, :findImage, :storePost, :getNewPost
end
