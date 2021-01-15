require "json"
require "crirc"
require "http/client"

include Crirc::Protocol

if ARGV.size == 0
  raise "No configuration file is provided"
end

secret = JSON.parse(File.read(ARGV[0]))

def twitch_id_by_name(name : String, secret): String | Nil
  response = HTTP::Client.get "https://api.twitch.tv/helix/users?login=#{URI.encode(name)}",
                             headers: HTTP::Headers{"Authorization" => "Bearer #{secret["twitch"]["token"].to_s}",
                                                    "Client-Id" => secret["twitch"]["clientId"].to_s}
  data = JSON.parse(response.body)["data"]?

  unless data.nil? || data.size == 0
    id = data[0]["id"]
    return id.to_s unless id.nil?
  end
end

client = Crirc::Network::Client.new nick: secret["twitch"]["account"].to_s,
                                    ip: "irc.chat.twitch.tv",
                                    port: 6697,
                                    ssl: true,
                                    pass: "oauth:#{secret["twitch"]["token"].to_s}"
client.connect
client.start do |bot|
  bot.on_ready do
    bot.join Chan.new("#tsoding")
  end.on("PING") do |msg|
    bot.pong(msg.message)
  end.on("PRIVMSG", message: /^!gnip */) do |msg|
    chan = msg.arguments if msg.arguments
    bot.reply msg, "gnop" if chan
  end.on("PRIVMSG", message: /^!weather (.*)/) do |msg, match|
    unless match.nil?
      location = match[1]
      response = HTTP::Client.get "http://wttr.in/#{URI.encode(location)}?format=4"
      bot.reply msg, response.body unless response.body.nil?
    end
  end.on("PRIVMSG", message: /^!id (.*)/) do |msg, match|
    unless match.nil?
      name = match[1]
      id = twitch_id_by_name(name, secret)
      bot.reply msg, "#{name} has id #{id}" unless id.nil?
    end
  end

  loop do
    m = bot.gets
    puts "> #{m}"
    break if m.nil?
    spawn { bot.handle(m.as(String)) }
  end
end
