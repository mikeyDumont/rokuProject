# Feature Request: Refactor Existing Recommendations/Guide Screen to Split-Screen List + Interactive Static Map UI

We want to refactor our existing local guide/recommendations screen in this Roku SceneGraph application. Please adapt this implementation to fit our current component, script names, and existing data structures.

---

### Context & Goal
Currently, our recommendations screen uses a standard List / Detail view. We want to convert this into a List / Map view where:
1. One side features the current vertical list of recommendations.
2. The other side displays our 1920x1080 static base map image with dynamic overlay pins (`Poster` nodes) representing the parent property (Like a 'You Are Here' kind of) and local recommendation spots.
3. As the user scrolls UP/DOWN through the list, the map dynamically highlights the active item's pin on the static map.
4. Pressing `OK` on a focused list item opens the detail card as pop-up modal on top of the map view. Pressing `BACK` closes the modal and returns focus to the navigation list.

---

### Bounding Box Configuration (Map Metadata)
The base map uses a 1920x1080 image centered at 34.17616, -94.71176 at Zoom Level 13. Use the following exact bounding box limits for screen pixel projection:

- `latMax` (Top Edge): **34.252815**
- `latMin` (Bottom Edge): **34.099435**
- `lonMin` (Left Edge): **-94.876555**
- `lonMax` (Right Edge): **-94.546965**

---

### Requirements & Functional Spec

#### 1. BrightScript Logic Updates (Update existing component BRS)
- **Lat/Long to Pixel Conversion Function:**
  Implement or update a helper function `ConvertLatLonToPixel(lat as Float, lon as Float) as Object` using linear interpolation based on the bounding box values above:
  ```brightscript
  function ConvertLatLonToPixel(lat as Float, lon as Float) as Object
      latMax = 34.252815
      latMin = 34.099435
      lonMin = -94.876555
      lonMax = -94.546965

      xRatio = (lon - lonMin) / (lonMax - lonMin)
      yRatio = (latMax - lat) / (latMax - latMin)

      pixelX = Fix(xRatio * 1920)
      pixelY = Fix(yRatio * 1080)

      ' Adjust for pin anchor offset (e.g., center/bottom pin tip)
      return [pixelX - 20, pixelY - 40]
  end function