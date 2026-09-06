sub init()
    m.currentTempLabel = m.top.findNode("currentTempLabel")
    m.currentConditionLabel = m.top.findNode("currentConditionLabel")
    m.humidityLabel = m.top.findNode("humidityLabel")
    m.windLabel = m.top.findNode("windLabel")
    m.sunriseLabel = m.top.findNode("sunriseLabel")
    m.sunsetLabel = m.top.findNode("sunsetLabel")
    m.weatherStatusLabel = m.top.findNode("weatherStatusLabel")
    m.forecastDayLabels = []
    m.forecastTempLabels = []
    m.forecastConditionLabels = []

    for i = 0 to 3
        m.forecastDayLabels.Push(m.top.findNode("forecastDay_" + i.ToStr()))
        m.forecastTempLabels.Push(m.top.findNode("forecastTemp_" + i.ToStr()))
        m.forecastConditionLabels.Push(m.top.findNode("forecastCondition_" + i.ToStr()))
    end for

    loadWeather()
end sub

sub loadWeather()
    m.currentTempLabel.text = "--"
    m.currentConditionLabel.text = "Loading current conditions..."
    m.weatherStatusLabel.text = ""

    if not IsWeatherConfigured()
        showWeatherError("Weather service is not configured")
        return
    end if

    m.weatherTask = CreateObject("roSGNode", "WeatherTask")
    m.weatherTask.observeField("state", "onWeatherTaskStateChanged")
    m.weatherTask.control = "RUN"
end sub

sub onWeatherTaskStateChanged()
    if m.weatherTask = invalid or m.weatherTask.state <> "stop" then return

    if not m.weatherTask.responseSuccess or m.weatherTask.responseJson = invalid
        showWeatherError("Live weather is temporarily unavailable")
        return
    end if

    weatherData = m.weatherTask.responseJson
    currentData = weatherData.current
    if currentData = invalid or currentData.main = invalid or currentData.weather = invalid or currentData.weather.Count() = 0
        showWeatherError("Live weather is temporarily unavailable")
        return
    end if

    m.currentTempLabel.text = Int(currentData.main.temp).ToStr() + " F"
    m.currentConditionLabel.text = currentData.weather[0].description
    m.humidityLabel.text = "Humidity: " + currentData.main.humidity.ToStr() + "%"
    m.windLabel.text = "Wind: " + Int(currentData.wind.speed).ToStr() + " mph " + GetWindDirection(currentData.wind.deg)
    m.sunriseLabel.text = "Sunrise: " + FormatWeatherTime(currentData.sys.sunrise, currentData.timezone)
    m.sunsetLabel.text = "Sunset: " + FormatWeatherTime(currentData.sys.sunset, currentData.timezone)
    m.weatherStatusLabel.text = "Live conditions from OpenWeather"

    if weatherData.forecast <> invalid and weatherData.forecast.list <> invalid
        timezoneOffset = 0
        if weatherData.forecast.city <> invalid and weatherData.forecast.city.timezone <> invalid
            timezoneOffset = weatherData.forecast.city.timezone
        end if
        populateForecast(weatherData.forecast.list, timezoneOffset)
    end if
end sub

sub populateForecast(entries as Object, timezoneOffset as Integer)
    dailyForecasts = {}
    forecastDates = []

    for each entry in entries
        if entry.dt_txt <> invalid and entry.main <> invalid and entry.weather <> invalid and entry.weather.Count() > 0
            dateKey = Left(entry.dt_txt, 10)
            if not dailyForecasts.DoesExist(dateKey)
                dailyForecasts[dateKey] = {
                    high: entry.main.temp_max,
                    low: entry.main.temp_min,
                    condition: entry.weather[0].description,
                    closestToNoon: 86401
                }
                forecastDates.Push(dateKey)
            else
                day = dailyForecasts[dateKey]
                if entry.main.temp_max > day.high then day.high = entry.main.temp_max
                if entry.main.temp_min < day.low then day.low = entry.main.temp_min
            end if

            day = dailyForecasts[dateKey]
            secondsFromMidnight = (entry.dt + timezoneOffset) Mod 86400
            if secondsFromMidnight < 0 then secondsFromMidnight = secondsFromMidnight + 86400
            distanceFromNoon = secondsFromMidnight - 43200
            if distanceFromNoon < 0 then distanceFromNoon = -distanceFromNoon
            if distanceFromNoon < day.closestToNoon
                day.condition = entry.weather[0].description
                day.closestToNoon = distanceFromNoon
            end if
        end if
    end for

    forecastIndex = 0
    for each dateKey in forecastDates
        if forecastIndex >= 4 then exit for
        day = dailyForecasts[dateKey]
        m.forecastDayLabels[forecastIndex].text = GetForecastLabel(forecastIndex, dateKey)
        m.forecastTempLabels[forecastIndex].text = Int(day.high).ToStr() + " / " + Int(day.low).ToStr() + " F"
        m.forecastConditionLabels[forecastIndex].text = day.condition
        forecastIndex = forecastIndex + 1
    end for
end sub

sub showWeatherError(message as String)
    m.currentTempLabel.text = "--"
    m.currentConditionLabel.text = message
    m.weatherStatusLabel.text = "Check the connection and weather service"
end sub

function GetForecastLabel(index as Integer, dateKey as String) as String
    if index = 0 then return "TODAY"
    if index = 1 then return "TOMORROW"
    return Mid(dateKey, 6, 5)
end function

function GetWindDirection(degrees as Dynamic) as String
    if degrees = invalid then return ""
    directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    directionIndex = Int((degrees + 22.5) / 45) Mod 8
    return directions[directionIndex]
end function

function FormatWeatherTime(unixTime as Dynamic, timezoneOffset as Dynamic) as String
    if unixTime = invalid or timezoneOffset = invalid then return "--"
    localSeconds = (unixTime + timezoneOffset) Mod 86400
    if localSeconds < 0 then localSeconds = localSeconds + 86400
    hour = Int(localSeconds / 3600)
    minute = Int((localSeconds - hour * 3600) / 60)
    suffix = "AM"
    displayHour = hour
    if hour >= 12 then suffix = "PM"
    if displayHour = 0 then displayHour = 12 else if displayHour > 12 then displayHour = displayHour - 12
    minuteText = minute.ToStr()
    if minute < 10 then minuteText = "0" + minuteText
    return displayHour.ToStr() + ":" + minuteText + " " + suffix
end function
