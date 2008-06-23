require 'open-uri'

class LastFmProfile  
  def initialize(profile)
    @profile = profile
  end
  
  def top_artists
    url = "http://ws.audioscrobbler.com/1.0/user/#{@profile}/topartists.txt?type=overall"
    top_artists = {}
    begin
      open(url).read.each_line do |line|
        columns = line.split(',')
        gid, weight = columns[0], columns[1].to_f
        top_artists[gid] = weight unless gid.blank?
      end
    rescue OpenURI::HTTPError
      return nil
    end
    top_artists
  end
end
