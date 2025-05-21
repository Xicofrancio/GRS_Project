# 1. Usa imagem leve do Node
FROM node:18-alpine

# 2. Define /app como diretório de trabalho
WORKDIR /app

# 3. Copia apenas o package.json e instala dependências
COPY package.json package-lock.json ./
RUN npm install

# 4. Copia todo o código da app
COPY . .

# 5. Expõe a porta em que a app corre
EXPOSE 3000

# 6. Comando de arranque
CMD ["npm", "start"]
