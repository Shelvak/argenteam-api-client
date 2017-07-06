## Milonga creada para bajar series 720 de argenteam

#### El script da la sgte prioridad
1) 720 + subtitulo
2) 720
3) no-720 + subtitulo
4) no-720

En cualquier caso de tener mas de 1 torrent "priorizado" por capitulo podremos elegir


lo unico que necesitas es crear un archivo `config.yml` con lo sgte
```yaml
host: ''  # default 127.0.0.1
port: ''  # default 9091
user: ''  # default admin
pass: ''  # default admin
```

# Uso
```ruby
$ irb
require './manso_script'
serie # Serie.search('Serie a ver')

series.seasons[indice].download # de querer solo 1 temporada especifica
series.download  # de querer toda la serie enterota
```

## TODO:
- darle forma de gema
- hacerla gema
- milonguear
- hacer el `print self` mas chiquito...
- Meter mejores mensajes

