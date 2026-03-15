#Limpa
cd /d/Documents/GitHub/rPetBr
rm -rf r-pet_tray/backup 
rm -f r-pet_tray/*.lps
rm -f r-pet_tray/*.res
rm -f r-pet_tray/*.exe
clear

#git config --global user.name "ribasoft"
#git config --global user.email "ribamarmsantos@gmail.com"
#ssh-keygen -t ed25519 -C "ribamarmsantos@gmail.com"

git config --global --add safe.directory /d/Documents/GitHub/rPetBr
git init
git branch -M main
git remote add origin git@github.com:RibaSoft/rPetBr.git
git pull origin main --allow-unrelated-histories

git status

# Manda Pro GitHub
echo "Precione Enter para Mandar para o Git..."
read -p "" 
clear
data_hora=$(date +"%Y%m%d_%H%M")
git add .
git commit -m "$data_hora"
git push -u origin main

echo "Enviado ao GitHub com sucesso!"
read -p "";
clear