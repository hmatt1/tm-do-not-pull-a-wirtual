[Setting name="Enable Clutch Time"]
bool clutchTimeEnabled = true;

[Setting name="Anchor Y position" min=0 max=1]
float anchorY = .5;

[Setting name="Font size" min=20]
float fontSize = 200;

[Setting name="Minimum opacity" min=0 max=1]
float minAlpha = 0.2;

[Setting name="Maximum opacity" min=0 max=1]
float maxAlpha = 0.5;

[Setting name="Music speed percentage" min=1]
int musicPitch = 170;

[Setting name="Seconds between flashes" min=0.001]
float flashSpeed = 0.5;

[Setting name="Clutch text"]
string clutchText = "Clutch Time";

bool hideCounterWithIFace = false;

bool inGame = false;
bool strictMode = false;

string curMap = "";

uint preCPIdx = 0;

uint curCP = 0;
uint maxCP = 0;
uint64 timestamp = 0;
vec4 overlayColor = randomColor();
vec4 textColor = randomTextColor();

bool musicSpeedUp = false;


bool debugEnabled = false;

int lastSource = 0;

void RenderMenuMain()
{
    if (debugEnabled) {

        string colorCode = "\\$0F7";
        string textPosition = "600";
    
        //string text = "hello world";
    
        string musicStatus;
        if (musicSpeedUp) {
            musicStatus = "true";
        } else {
            musicStatus = "false";
        }
    
        string text = "curCP: " + Text::Format("%d", curCP) + " maxCP: " + Text::Format("%d", maxCP) +  " timestamp: " + Text::Format("%d", timestamp) + " music: " + musicStatus;
    	auto textSize = Draw::MeasureString(text);
    
    	auto pos_orig = UI::GetCursorPos();
    	UI::SetCursorPos(vec2(UI::GetWindowSize().x - textSize.x - Text::ParseInt(textPosition), pos_orig.y));
    	UI::Text(text);
    	UI::SetCursorPos(pos_orig);
    
    }
}

vec4 randomColor() {
    float red = Math::Rand(0.0, 1.0);
    float green = Math::Rand(0.0, 1.0);
    float blue = Math::Rand(0.0, 1.0);
    float transparency = Math::Rand(minAlpha, maxAlpha);
    return vec4(red, green, blue, transparency);
}

vec4 randomTextColor() {
    float red = Math::Rand(0.0, 1.0);
    float green = Math::Rand(0.0, 1.0);
    float blue = Math::Rand(0.0, 1.0);
    return vec4(red, green, blue, 1);
}

void speedUpMusic(bool force = false) {

    if (!musicSpeedUp || force) {
        musicSpeedUp = true;
        // speed up
        setPitch(float(musicPitch) / 100);
    }

    return;
}

void resetMusic() {
    if (musicSpeedUp) {
        // slow down
        musicSpeedUp = false;
        setPitch(1.0);
    }
    return;
}

void setPitch(float pitch) {
    auto app = GetApp();
    for (uint i = 0; i < app.AudioPort.Sources.Length; i++) {
      auto source = app.AudioPort.Sources[i];
    
      // Get the sound that the source can play
      auto sound = source.PlugSound;
    
      // Check if its file is an .ogg file
      if (cast<CPlugFileOggVorbis>(sound.PlugFile) is null) {
        // Skip if it's not an ogg file
        continue;
      }

      /* 
      Check is source playing and is it in the music group.
      This is *likely* to only be the music, as opposed to the above. - Kodey.Kayla
      */
      if (source.BalanceGroup == EAudioBalanceGroup::Music && source.IsPlaying) {
        source.Pitch = pitch;
        lastSource = i;
      }

   }
}
void Render() {
  if(clutchTimeEnabled && inGame && curCP == maxCP) {
 //if(clutchTimeEnabled && inGame) {

    speedUpMusic();

    uint64 now = Time::get_Now();

    if (now >= timestamp + flashSpeed * 1000) {
        timestamp = now;
        overlayColor = randomColor();
        textColor = randomTextColor();
    }

    nvg::BeginPath();
    nvg::Rect(0, 0, Draw::GetWidth(), Draw::GetHeight());
    nvg::FillColor(overlayColor);
    nvg::Fill();
    nvg::ClosePath();
    
    nvg::FillColor(textColor);
    nvg::FontSize(fontSize);
    nvg::TextAlign(nvg::Align::Center);
    nvg::TextBox(0, anchorY * Draw::GetHeight(), Draw::GetWidth(), clutchText);

    
  } else {
      resetMusic();
  }
}

void Update(float dt) {
  auto app = GetApp();
  calculateCheckpoints(dt);
  if (musicSpeedUp) {
    if (app.AudioPort.Sources[lastSource].Pitch == 1) {
      speedUpMusic(true);
    }
  }
}


// Code in this function is from the Checkpoint Counter plugin: https://openplanet.nl/files/79 
void calculateCheckpoints(float dt) {
#if TMNEXT
  auto playground = cast<CSmArenaClient>(GetApp().CurrentPlayground);
  
  if(playground is null
     || playground.Arena is null
     || playground.Map is null
     || playground.GameTerminals.Length <= 0
     || playground.GameTerminals[0].UISequence_Current != CGamePlaygroundUIConfig::EUISequence::Playing
     || cast<CSmPlayer>(playground.GameTerminals[0].GUIPlayer) is null) {
    inGame = false;
    return;
  }
  
  auto player = cast<CSmPlayer>(playground.GameTerminals[0].GUIPlayer);
  auto scriptPlayer = cast<CSmPlayer>(playground.GameTerminals[0].GUIPlayer).ScriptAPI;
  
  if(scriptPlayer is null) {
    inGame = false;
    return;
  }
  
  if(hideCounterWithIFace) {
    if(playground.Interface is null || Dev::GetOffsetUint32(playground.Interface, 0x1C) == 0) {
      inGame = false;
      return;
    }
  }
  
  if(player.CurrentLaunchedRespawnLandmarkIndex == uint(-1)) {
    // sadly, can't see CPs of spectated players any more
    inGame = false;
    return;
  }
  
  MwFastBuffer<CGameScriptMapLandmark@> landmarks = playground.Arena.MapLandmarks;

  if(!inGame && (curMap != playground.Map.IdName || GetApp().Editor !is null)) {
    // keep the previously-determined CP data, unless in the map editor
    curMap = playground.Map.IdName;
    preCPIdx = player.CurrentLaunchedRespawnLandmarkIndex;
    curCP = 0;
    maxCP = 0;
    timestamp = 0;
    strictMode = true;
    resetMusic();
    
    array<int> links = {};
    for(uint i = 0; i < landmarks.Length; i++) {
      if(landmarks[i].Waypoint !is null && !landmarks[i].Waypoint.IsFinish && !landmarks[i].Waypoint.IsMultiLap) {
        // we have a CP, but we don't know if it is Linked or not
        if(landmarks[i].Tag == "Checkpoint") {
          maxCP++;
        } else if(landmarks[i].Tag == "LinkedCheckpoint") {
          if(links.Find(landmarks[i].Order) < 0) {
            maxCP++;
            links.InsertLast(landmarks[i].Order);
          }
        } else {
          // this waypoint looks like a CP, acts like a CP, but is not called a CP.
          if(strictMode) {
            warn("The current map, " + string(playground.Map.MapName) + " (" + playground.Map.IdName + "), is not compliant with checkpoint naming rules."
                 + " If the CP count for this map is inaccurate, please report this map to Phlarx#1765 on Discord.");
          }
          maxCP++;
          strictMode = false;
        }
      }
    }
  }
  inGame = true;
  
  /* These are all always length zero, and so are useless:
  player.ScriptAPI.RaceWaypointTimes
  player.ScriptAPI.LapWaypointTimes
  player.ScriptAPI.CurrentLapWaypointTimes
  player.ScriptAPI.PreviousLapWaypointTimes
  player.ScriptAPI.Score.BestRaceTimes
  player.ScriptAPI.Score.PrevRaceTimes
  player.ScriptAPI.Score.BestLapTimes
  player.ScriptAPI.Score.PrevLapTimes
  */
  
  if(preCPIdx != player.CurrentLaunchedRespawnLandmarkIndex && landmarks.Length > player.CurrentLaunchedRespawnLandmarkIndex) {
    preCPIdx = player.CurrentLaunchedRespawnLandmarkIndex;
    
    if(landmarks[preCPIdx].Waypoint is null || landmarks[preCPIdx].Waypoint.IsFinish || landmarks[preCPIdx].Waypoint.IsMultiLap) {
      // if null, it's a start block. if the other flags, it's either a multilap or a finish.
      // in all such cases, we reset the completed cp count to zero.
      curCP = 0;
    } else {
      curCP++;
    }
  }
#endif
}
