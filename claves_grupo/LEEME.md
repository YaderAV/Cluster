# Claves públicas del grupo

Cada integrante deja aquí su clave **pública** (`nombre.pub`) para poder entrar a `main` por SSH.

En Windows (PowerShell):

```powershell
ssh-keygen -t ed25519          # Enter a todo, si no tienes clave
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

Copia esa línea a `claves_grupo/<tu-nombre>.pub`. Nunca subas el archivo sin `.pub`, que es la clave privada.

- **Si la clave está aquí antes de crear el clúster**, `crear_cluster.ps1` la instala sola.
- **Si se agrega después**, quien ya tiene acceso la añade así:

  ```powershell
  Get-Content claves_grupo\<nombre>.pub | ssh -F claves\ssh_config main "cat >> ~/.ssh/authorized_keys"
  ```
