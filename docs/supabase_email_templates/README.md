# Template de email Supabase — SAUH

## Onde aplicar

No Supabase Dashboard:

1. Abre o projeto Supabase.
2. Vai a **Authentication > Email Templates**.
3. Escolhe o template **Confirm signup**.
4. No campo **Subject**, cola o conteúdo de `confirmation_email_subject.txt`.
5. No campo **Message body**, cola o conteúdo de `confirmation_email.html`.
6. Guarda e envia um email de teste.

## Variáveis usadas

- `{{ .Email }}` mostra o email do utilizador.
- `{{ .ConfirmationURL }}` é o link de confirmação gerado pelo Supabase.

## Notas importantes

- Mantém `{{ .ConfirmationURL }}` exatamente como está, porque o Supabase substitui essa variável no envio.
- Se configurares Android/iOS com deep links, atualiza também o **Site URL** e os **Redirect URLs** nas definições de autenticação do Supabase.
- Se o teu fornecedor SMTP tiver tracking de links ativo, desativa o tracking para emails de autenticação.
