require "json"
require "crirc"
require "http/client"

include Crirc::Protocol

if ARGV.size == 0
  raise "No configuration file is provided"
end

secret = JSON.parse(File.read(ARGV[0]))
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
  end

  loop do
    m = bot.gets
    puts "> #{m}"
    break if m.nil?
    spawn { bot.handle(m.as(String)) }
  end
end
