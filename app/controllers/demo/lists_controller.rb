require 'ostruct'

class Demo::ListsController < ApplicationController

  def add
    a = OpenStruct.new
    a.name = "People taking video game journalism a bit too seriously"
    a.description = "The title says it all, doesn't it? This is another one that could've been a lot longer..."
    a.accounts = [ "ghostlev", "AmazingKungFuCt", "Kallistrix", "gameragodzilla", "OfGloriousLife", "sanc", "Gynocentrism", "Nephanor", "subtleblend", "VOR467" ]
    a.owner = "KnownTrollApp"
    a.owner_name = "KnownTroll Admin"
    a.image_url = "https://pbs.twimg.com/profile_images/523927769919401984/NArM1O-p_normal.png"

    @fake_additional_lists = [a]

    render layout: "demo"
  end

  def edit
    render layout: "demo"
  end

  def index
    a = OpenStruct.new
    a.name = "Nazis"
    a.description = "Man, do I hate Nazis"
    a.accounts = [ "ANP14", "MeinVaterland_", "ANP_Man", "White_History", "burks_jay", "WhiteDawn1488", "JoshyNatSoc",
      "schwarzengel88", "SCORP_1488", "Jack_1488", "BenH1488", "ANP_Jaiden", "Rakaboom88"]

    b = OpenStruct.new
    b.name = "General Misogyny"
    b.description = "This list could be a whole lot longer..."
    b.accounts = [ "Amir2Real", "HillDamari", "itsyaboylamar", "ScoutThis", "GregPoppabitch", "CauseWereGuys", "MalesAdvice" ]
    b.owner = "KnownTrollApp"
    b.owner_name = "KnownTroll Admin"
    b.image_url = "https://pbs.twimg.com/profile_images/523927769919401984/NArM1O-p_normal.png"

    @fake_created_lists = [a]
    @fake_subscribed_lists = [b]

    render layout: "demo"
  end

  def new
    render layout: "demo"
  end

end