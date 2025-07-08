apt update
apt install flutter 
git clone ##root repo i.e flutter_upi as og_repo
cd og_repo
cd flutter_upi ## the main flutter project
flutter build web --release
cd ..
rm -rf ./UPI-QR-MAKER/*
mkdir UPI-QR-MAKER
##copy every thing from the ./flutter_upi/build/web/* to UPI-QR-MAKER
## clone the pages repo i.e mrrohanbatra.github.io as pages_repo
cd pages_repo 
rm -rf ./UPI-QR-MAKER/*
mkdir UPI-QR-MAKER
##copy every thing from the flutter_upi/build/web/* to UPI-QR-MAKER in the pages_repo and commit everything 
