# Estrutura Firestore para o SAUH

O projeto atual continua a compilar sem dependências Firebase porque a app já estava ligada ao Supabase. A camada `AuthService`, `HospitalService` e `PermissionService` simula localmente a estrutura que deve ser gravada no Firestore quando adicionares `firebase_auth`, `cloud_firestore` e a configuração do teu projeto Firebase.

## Coleções

### `hospitals`

- `hospitalId`
- `nome`
- `morada`
- `contacto`
- `codigoHospital`
- `ativo`
- `criadoPor`
- `dataCriacao`

### `users`

- `userId`
- `nome`
- `email`
- `role`
- `hospitalId`
- `ativo`
- `departamento`
- `criadoPor`
- `dataCriacao`

### `patients`

- `patientId`
- `nome`
- `idade`
- `hospitalId`
- `estado`
- `prioridade`
- `cama`
- `criadoPor`
- `dataEntrada`

### `alerts`

- `alertId`
- `patientId`
- `hospitalId`
- `tipo`
- `gravidade`
- `mensagem`
- `visto`
- `vistoPor`
- `dataCriacao`

## Cargos usados na urgência

- `admin_hospital` — Coordenador da Urgência
- `diretor_clinico` — Diretor Clínico da Urgência
- `chefe_enfermagem` — Chefe de Enfermagem
- `medico` — Médico de Urgência
- `enfermeiro` — Enfermeiro
- `triagem` — Profissional de Triagem
- `tecnico_emergencia` — Técnico de Emergência
- `administrativo` — Administrativo
- `auxiliar` — Assistente Operacional

## Regras

As regras iniciais estão em `docs/firestore.rules`. Ajusta-as no Firebase Console antes de usar dados reais.
