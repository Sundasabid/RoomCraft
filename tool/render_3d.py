# Renders the 3D bundle in headless Chrome for a quick look without a phone.
# Usage: python3 tool/render_3d.py <out-dir> [corner eye warn dark ...]
import json, subprocess, sys
S = sys.argv[1]
cat=[("bed",1.6,2.0,1.0,False),("sofa",2.0,0.9,0.85,False),("chair",0.5,0.5,0.9,False),("wardrobe",1.2,0.6,2.0,False),("bookshelf",0.8,0.3,1.8,False),("tv_unit",1.5,0.4,0.5,False),("desk",1.4,0.7,0.75,False),("dining_table",1.6,0.9,0.75,False),("coffee_table",1.0,0.5,0.45,False),("rug",2.0,1.4,0.02,True),("plant",0.4,0.4,1.0,False),("floor_lamp",0.35,0.35,1.6,False)]
fin=[("oak","#b98b5e",.6),("walnut","#7a5230",.55),("white_lacquer","#f4f1ea",.25),("sage_fabric","#6b8f71",.95),("beige_linen","#d9c8aa",.95),("light_oak","#d2b48c",.6),("warm_white","#f7f3ec",.9),("sand","#e6d9c3",.9),("sage_wall","#a9bfa9",.9)]
def it(i,c,x,z,r=0,f="oak"): return {"id":i,"type":"item","parentId":"room_a","visible":True,"catalogueId":c,"x":x,"z":z,"rotation":r,"finish":f,"locked":False}
def scene(lamp=(0.35,3.85), light="day"):
  nodes={"room_a":{"id":"room_a","type":"room","corners":[[0,0],[5.0,0],[5.0,4.2],[0,4.2]],"wallHeight":2.6,"floorFinish":"oak","wallFinish":"warm_white","lighting":light},
  "op_d":{"id":"op_d","type":"opening","kind":"door","wallIndex":3,"offset":0.9,"width":0.9,"height":2.1,"sillHeight":0},
  "op_w":{"id":"op_w","type":"opening","kind":"window","wallIndex":0,"offset":2.5,"width":1.2,"height":1.2,"sillHeight":0.9},
  "op_w2":{"id":"op_w2","type":"opening","kind":"window","wallIndex":1,"offset":2.0,"width":1.2,"height":1.2,"sillHeight":0.9}}
  for i in [it("i1","bed",3.95,1.05,0,"beige_linen"),it("i2","sofa",1.9,3.7,180,"sage_fabric"),it("i3","wardrobe",0.65,0.35,0,"walnut"),it("i4","rug",2.2,2.6,0,"beige_linen"),it("i5","coffee_table",2.0,2.6,0,"oak"),it("i6","plant",4.7,3.9,0,"white_lacquer"),it("i7","floor_lamp",lamp[0],lamp[1],0,"white_lacquer"),it("i8","bookshelf",2.0,0.2,0,"oak"),it("i9","chair",4.55,2.6,270,"oak"),it("i10","desk",4.6,2.6,270,"walnut"),it("i11","tv_unit",2.2,1.4,0,"white_lacquer")]:
    nodes[i["id"]]=i
  return {"rootId":"room_a","nodes":nodes}
def init(dark=False, lamp=(0.35,3.85), light="day"):
  return {"t":"init","mode":"editor","reduceMotion":True,"debug":False,
   "palette":{"background":"#151a16" if dark else "#f5efe6","primary":"#8db393" if dark else "#6b8f71","warning":"#c8553d"},
   "catalogue":[{"id":a,"width":w,"depth":d,"height":h,"floorOnly":fo} for a,w,d,h,fo in cat],
   "finishes":[{"id":a,"hex":h,"roughness":r} for a,h,r in fin],"scene":scene(lamp, light)}
html=open(__import__('os').path.join(__import__('os').path.dirname(__file__), '..', 'assets', 'web3d', 'index.html')).read()
shots={
 "corner":[init()],
 "eye":[init(),{"t":"camera.preset","name":"eye"}],
 "eye_lampmoved":[init(lamp=(2.6,3.0)),{"t":"camera.preset","name":"eye"}],
 "warn":[init(),{"t":"selection.set","ids":["i5"]},{"t":"warnings.set","ids":["i9","i10"]}],
 "dark":[init(dark=True)],
 "light_golden":[init(light="golden")],
 "light_evening":[init(light="evening")],
 "light_soft":[init(light="soft")],
}
only=sys.argv[2:] or list(shots)
for name in only:
  js="<script>setTimeout(function(){"+"".join("window.roomcraft.receive(%s);"%json.dumps(json.dumps(m)) for m in shots[name])+"},300);</script>"
  open(f"{S}/{name}.html","w").write(html.replace("</body>",js+"</body>"))
  subprocess.run(["google-chrome","--headless=new","--use-angle=swiftshader","--enable-unsafe-swiftshader","--window-size=540,700","--virtual-time-budget=4000",f"--screenshot={S}/{name}.png",f"file://{S}/{name}.html"],capture_output=True)
  print(name)
