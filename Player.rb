#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Thu 21 Mar 2019 
# Description: Class representing a single player
#

require "squid"
require "prawn"

require "./Constants.rb"
require "./Trophies.rb"
require "./Experience.rb"
require "./Victories.rb"
require "./Brawler.rb"
require "./WebsiteInspector.rb"

class Player

    attr_accessor :id, :name, :image, :trophies, :experience, :victories, :brawlers

    def initialize( id )
        @id = id
        @name = ""
        @image = ""
        @trophies = Trophies.new()
        @experience = Experience.new()
        @victories = Victories.new()
        @brawlers = Brawlers.new()
    end

    def read_stats( online = false )
        inspector = WebsiteInspector.new()
        #   inspector.read_stats_brawland( id, self )
        inspector.read_stats_brawlstats( @id, self, online )
        puts "====================="
        puts "#{self}"
    end

    def get_brawler( name )
        @brawlers.get_brawler( name )
    end

    def printable()
        result = "#{@name} (##{@id})\n"
        result += @experience.printable() + "\n"
        result += @trophies.printable() + "\n"
        result += @victories.printable() + "\n"
        result += @brawlers.printable() + "\n"
        return result
    end

    def printable_intro()
        return "#{@name} (##{@id}) #{@trophies.printable()}"
    end

    def update_csv_stats()
        # Looking for the player file, if it doesn't exist it will get created
        # Opening the file with append does what I need without checking the
        # existence of the file
        
        # I could avoid printing the name and tag since the file is personal of
        # that player, but in this way I have data format consistence through
        # all the files
        File.open( "#{EXPORT_FILE_DIR}/#{id}#{EXPORT_FILE_EXT}", "a" ) do |export_file|
            export_file.write( "#{Time.now.strftime( "%Y/%m/%d_%H:%M" )}\t#{export_to_csv()}\n" )
        end
    end

    def export_to_csv()
        result = "#{name}\t#{id}\t#{trophies.export_to_csv()}\t"
        result += "#{victories.export_to_csv()}\t"
        result += "#{brawlers.export_to_csv()}"
        return result
    end
end

class Players
    def initialize( ids )
        @player_list = Array.new()
        ids.each do |id|
            @player_list.append( Player.new( id ) )
            @player_list[ -1 ].read_stats()
        end
    end

    def update_stats()
        @player_list.each{ |player| player.read_stats( true ) }
    end

    def get_player_by_name( name )
        @player_list.each do |player|
            if player.name == name then
                return player
            end
        end
        return "Player not found."
    end

    def get_player_by_id( id )
        @player_list.each do |player|
            if player.id == id then
                return player
            end
        end
        return "Player not found."
    end

    def get_player_name( id )
        return get_player_by_id( id ).name
    end

    # Comparing all players to the given one
    def compare_to( id )
        player_comparisons = Array.new()
        ref_player = get_player_by_id( id )
        @player_list.each do |player|
            if player.id != id then
                compared = Player.new( "#{id}-##{player.id}" )
                compared.name = "#{ref_player.name} vs #{player.name}"
                compared.trophies = Trophies.compare( ref_player.trophies, player.trophies )
                compared.experience = Experience.compare( ref_player.experience, player.experience )
                compared.victories = Victories.compare( ref_player.victories, player.victories )
                compared.brawlers = Brawlers.compare( ref_player.brawlers, player.brawlers )

                player_comparisons.append( compared )
            end
        end
        return player_comparisons
    end

    def printable_intro()
        result = "Player list:\n"
        @player_list.each do |player|
            result +=  " - " + player.printable_intro() + "\n"
        end
        return result
    end

    def printable_full()
        result = "Player list:\n"
        @player_list.each do |player|
            result +=  " => " + player.printable() + "\n"
        end
        return result
    end

    def update_players_csv_stats()
        print "Updating players stats."
        @player_list.each do |player|
            player.update_csv_stats()
            print "."
        end
        puts "DONE (•̀o•́)ง"
    end

    def export_to_csv()
        print "Exporting data to '#{EXPORT_FILE_DIR}/#{EXPORT_FILE_NAME}#{EXPORT_FILE_EXT}'..."
        File.open( "#{EXPORT_FILE_DIR}/#{EXPORT_FILE_NAME}#{EXPORT_FILE_EXT}", "w" ) do |export_file|
            # Writing the header as first line of the document
            export_file.write( "#{EXPORT_FILE_HEADER_LINE}" )
            @player_list.each do |player|
                export_file.write( "#{player.export_to_csv()}\n" )
            end
        end
        puts "DONE (•̀o•́)ง"
    end

    def create_graphs( player_id )
        print "Creating cute graphs for the player '#{player_id}'..."

        # Creating all data used to print afterwards
        players_data_series = Hash.new
        data_selectors = [ "trophies", "max_trophies" ]
        data_selectors.each do |data_selector|
            players_data_series[ data_selector ] = Hash.new
            @player_list.each do |player|
                players_data_series[ data_selector ][ player.name ] = Hash.new
                CHARS.each do |char_name, _, _|
                    case data_selector
                    when "trophies"
                        players_data_series[ data_selector ][ player.name ][ char_name ] = player.get_brawler( char_name ).trophies.trophies
                    when "max_trophies"
                        players_data_series[ data_selector ][ player.name ][ char_name ] = player.get_brawler( char_name ).trophies.max_trophies
                    end
                end
            end
        end
        
        # Player page

        # Comparisons with other players, one page per player
        # Creating a graph with all brawlers on the x-axis and their trophies on
        # the y-axis
        Prawn::Document.generate( "#{PDF_FILE_DIR}/#{get_player_name( player_id )}#{PDF_FILE_EXT}",
                                  :page_layout => :landscape ) do |output_file|
            # Cycling on the brawlers
            # data = { player_id => { x => y, ... }, ... }
            @player_list.each do |player|
                if player.id != player_id then
                    #   puts "Pre title: #{output_file.cursor} #{output_file.cursor.class}"
                    output_file.text( "#{get_player_name( player_id )} [#{get_player_by_id( player_id ).trophies.trophies}] vs. #{player.name} [#{player.trophies.trophies}]", :align => :center )
                    #   puts "Pre graph: #{output_file.cursor}"
                    output_file.chart( players_data_series[ "trophies" ].select{ |k,v| k == get_player_name( player_id ) or k == player.name } )
                    #   puts "Pre caption: #{output_file.cursor}"
                    output_file.text( "Current trophies", :align => :center )
                    #   puts "Pre graph: #{output_file.cursor}"
                    output_file.chart( players_data_series[ "max_trophies" ].select{ |k,v| k == get_player_name( player_id ) or k == player.name },
                                       type: :line,
                                       line_widths: [ 2, 2 ],
                                       labels: [ true, true ],
                                       legend: false )
                    #   puts "Pre caption: #{output_file.cursor}"
                    output_file.text( "Max trophies", :align => :center )
                    #   puts "End page: #{output_file.cursor}"
                    #   output_file.start_new_page()
                    #   puts "New page: #{output_file.cursor}"
                    
                    # TODO: This library does not allow me to choose the type of
                    # style for each data series. Fix it to create a single
                    # graph with all the information in it, only if the result
                    # is not too messy.
                    #   output_data = Hash.new
                    #   #   settings = { "type" => { :stack, :line, :point, :point }, "labels" => { false, false, true, true } }
                    #   data_selectors.each do |data_selector|
                    #       #   puts "Merging #{data_selector}"
                    #       #   composing = players_data_series[ data_selector ].select{ |k, v| k == get_player_name( player_id ) or k == player.name }
                    #       #   composing = composing.map{ |k, v| composing[ "max#{k}" ] = v }
                    #       #   puts "#{composing}"
                    #       if data_selector.include?( "max" ) then
                    #           output_data[ "max#{player.name}" ] = players_data_series[ data_selector ][ player.name ]
                    #           output_data[ "max#{get_player_name( player_id )}" ] = players_data_series[ data_selector ][ get_player_name( player_id ) ]
                    #       else
                    #           output_data.merge!( players_data_series[ data_selector ].select{ |k, v| k == get_player_name( player_id ) or k == player.name } )
                    #       end
                    #   end

                    #   output_file.chart( output_data,
                    #                      type: [ :line, :line, :point, :point ],
                    #                      line_widths: [ 2, 2, 1, 1 ],
                    #                      labels: [ false, false, true, true ] )

                    #   output_file.start_new_page()
                end
            end
        end
        puts "DONE (•̀o•́)ง"
    end
end