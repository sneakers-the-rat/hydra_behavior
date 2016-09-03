function [im_scaled] = scaleImage(im,outputsz,rho)

im = imresize(im,rho,'nearest');

imsz = size(im);

im_scaled = zeros(size(im,1)+outputsz(1),size(im,2)+outputsz(2));
im_scaled(round((size(im_scaled,1)-imsz(1))/2)+1:...
    round((size(im_scaled,1)-imsz(1))/2)+imsz(1),...
    round((size(im_scaled,2)-imsz(2))/2)+1:...
    round((size(im_scaled,2)-imsz(2))/2)+imsz(2)) = im;
im_scaled = im_scaled(round((size(im_scaled,1)-outputsz(1))/2)+1:...
    round((size(im_scaled,1)-outputsz(1))/2)+outputsz(1),...
    round((size(im_scaled,2)-outputsz(2))/2)+1:...
    round((size(im_scaled,2)-outputsz(2))/2)+outputsz(2));

end