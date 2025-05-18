# Consulta Intelli Metrics

Repo de backend em Flask que serve de API para os produtos Intelli Metrics.

## Como rodar localmente

1. Pegue o .env file e salve-o no root do projeto. Peça para algum membro do time que te envie de forma segura (https://onetimesecret.com/ eh uma opçao). NUNCA coloque o `.env` no GitHub!! Se colocar por acidente, mesmo se deletar o commit depois, imediatamente fale para alguem para que troquemos o password da DB.
2. Se quiser rodar em um venv (instala dependencias localmente nesse projeto, nao no global da sua maquina)
   1. `python -m venv env` -> roda apenas uma vez
   2. `source env/bin/activate` -> tem que rodar toda vez que for rodar o projeto
3. Instalar dependencias:
   - `pip install pip-tools` -> instala o pip-tools (rode apenas uma vez)
   - `pip-compile requirements.in` -> gera o requirements.txt com todas as dependencias
   - `pip-sync requirements.txt` -> instala exatamente as dependencias necessarias e remove as que nao sao usadas
4. `python run.py`

> **Nota**: Certifique-se que o `gunicorn` está listado no `requirements.in`, pois ele é necessário para o deploy no Heroku.

## Postman
https://intellu-metrics.postman.co/workspace/Team-Workspace~85384cd8-2bce-4e1f-81b2-c5b4bc0f07ba/collection/3598753-2d7da8af-fdc8-498f-a51a-3b10f2301865?action=share&source=copy-link&creator=3598753&active-environment=63e89027-d8a4-4e3c-81bf-758579ab42a0