content = open("/app/app/core/schemas.py", "r").read()
old = "    timestamp: str"
new = "    timestamp: str\n    total_muestras: Optional[int] = None\n    entrenado_con_sinteticos: Optional[bool] = None"
content = content.replace(old, new, 1)
open("/app/app/core/schemas.py", "w").write(content)
print("Hecho")
