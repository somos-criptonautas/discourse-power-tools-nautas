# Power Tools Nautas

[ENGLISH](README.md) | **ESPAÑOL**

Mantenido por Criptonautas. Sin afiliación ni respaldo de Discourse (Civilized Discourse Construction Kit, Inc.).

El plugin de Discourse detrás de [Criptonautas](https://criptonautas.co): herramientas de moderación, funciones de privacidad y un cliente liviano para teléfonos, en una sola instalación. Cada función tiene su propio interruptor, así que solo usas lo que necesitas.

## Qué incluye

**Para moderadores**

- **[Herramientas de moderación](docs/features/moderator-tools.md).** Respuestas privadas a personas elegidas dentro de un tema, notas privadas del equipo, avisos cuando otro moderador actúa, listas de verificación antes de publicar y herramientas de tema como mensajes al pie y aprobación de respuestas.
- **[Mini-mod](docs/features/mini-mod.md).** Permisos extra para quienes moderan una sola categoría: gestionarla, mover temas, etiquetas. Nunca más allá de lo que pueden ver.
- **[Dislike](docs/features/dislike.md).** En las categorías que elijas, los me gusta dejan de contar: sin notificaciones, sin historial, sin totales.

**Para miembros**

- **[Dumbcourse](docs/features/dumbcourse.md).** El foro en `/dumb`, lo bastante liviano para teléfonos básicos y navegadores antiguos, con un ranking opcional. En foros que inician sesión mediante SSO, usa el inicio de sesión del propio foro.
- **[Búsqueda inteligente](docs/features/smart-search.md).** Cuando una búsqueda encuentra muy poco, vuelve a intentarlo con sinónimos, en el idioma de quien busca (inglés o español).
- **[Avisos de escritorio](docs/features/popups.md).** Una pequeña tarjeta en la esquina cuando llega una notificación.
- **[REQ-PM](docs/features/reqpm.md).** Los miembros se piden datos de contacto entre sí y eligen exactamente qué compartir. Desactivado por defecto.

**En segundo plano**

- **[Disteleplus](docs/features/disteleplus.md).** Una sala de chat del equipo reflejada en ambos sentidos con un grupo de Telegram, con la cola de revisión también en Telegram.
- **[Another SMTP](docs/features/another-smtp.md).** Envía el correo del foro a través de otro servidor de correo.
- **[Ajustes del traductor](docs/features/translator-tweaks.md).** Un proxy para las peticiones a Google del plugin Translator.

También funciona junto a [discourse-category-lockdown-nautas](https://github.com/somos-criptonautas/discourse-category-lockdown-nautas): las respuestas privadas siguen visibles para su audiencia dentro de temas bloqueados.

La interfaz está disponible en inglés y español.

## Instalación

Añade el plugin a tu `app.yml` y reconstruye:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/somos-criptonautas/discourse-power-tools-nautas.git jtech-tools
```

```bash
cd /var/discourse
./launcher rebuild app
```

Clónalo en una carpeta llamada `jtech-tools`, el nombre interno del plugin; Discourse avisa cuando la carpeta y el nombre del plugin no coinciden, y construye la dirección de la hoja de estilos del plugin a partir de la carpeta.

## Activar funciones

Todo está en **Admin → Plugins → Power Tools Nautas**, una pestaña por función. `jtech_enabled` es el interruptor general: apagado detiene todo a la vez, incluidos los cambios de permisos y los trabajos en segundo plano. Desactivar las respuestas privadas nunca hace pública una existente.

## Desarrollo

Lee las [reglas del repositorio](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md) y [EDITION.md](EDITION.md), que explica cómo este repo se sincroniza con el código en el que se basa. La documentación para desarrolladores está en [docs/](docs/README.md). Problemas de seguridad: consulta [SECURITY.md](SECURITY.md).

## Licencia

[GPL-3.0](LICENSE), heredada de [JtechTools](https://github.com/TripleU613/JtechTools). Autores originales: TripleU, Shalom Karr y Ars18.

Texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
