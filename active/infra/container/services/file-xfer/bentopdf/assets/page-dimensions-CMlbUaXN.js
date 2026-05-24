import{n as C,f as L,c as y,i as v,A as z,C as x}from"./main-Dzxg2eZZ.js";import"./mobileMenu-CQFcDk7p.js";import"./full-width-CrKHpSp0.js";import"./simple-mode-footer-rW7ABm1-.js";import{P as $}from"./PDFButton-_8Cap8jz.js";import"./index-DMQTJy3b.js";const d={file:null,pdfDoc:null};let l=[];function w(o,e){return(o/e).toFixed(3)}function S(o,e,t){const n=o*e;let i=0,s="";switch(t){case"in":i=n/5184,s="in²";break;case"mm":i=n/5184*(25.4*25.4),s="mm²";break;case"px":const r=96/72;i=n*(r*r),s="px²";break;default:i=n,s="pt²";break}return`${i.toFixed(2)} ${s}`}function B(){const o=l.length,e=new Map;l.forEach(n=>{const i=`${n.width.toFixed(2)}x${n.height.toFixed(2)}`,s=`${n.standardSize} (${n.orientation})`;e.set(i,{count:(e.get(i)?.count||0)+1,label:s,width:n.width,height:n.height})});const t=e.size>1;return{totalPages:o,uniqueSizesCount:e.size,uniqueSizes:Array.from(e.values()),hasMixedSizes:t}}function I(){const o=document.getElementById("dimensions-summary");if(!o)return;const e=B();let t=`
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
      <div class="bg-gray-900 border border-gray-700 rounded-lg p-4">
        <p class="text-sm text-gray-400 mb-1">Total Pages</p>
        <p class="text-2xl font-bold text-white">${e.totalPages}</p>
      </div>
      <div class="bg-gray-900 border border-gray-700 rounded-lg p-4">
        <p class="text-sm text-gray-400 mb-1">Unique Page Sizes</p>
        <p class="text-2xl font-bold text-white">${e.uniqueSizesCount}</p>
      </div>
      <div class="bg-gray-900 border border-gray-700 rounded-lg p-4">
        <p class="text-sm text-gray-400 mb-1">Document Type</p>
        <p class="text-2xl font-bold ${e.hasMixedSizes?"text-yellow-400":"text-green-400"}">
          ${e.hasMixedSizes?"Mixed Sizes":"Uniform"}
        </p>
      </div>
    </div>
  `;e.hasMixedSizes&&(t+=`
      <div class="bg-yellow-900/20 border border-yellow-500/30 rounded-lg p-4 mb-4">
        <div class="flex items-start gap-3">
          <i data-lucide="alert-triangle" class="w-5 h-5 text-yellow-400 mt-0.5 flex-shrink-0"></i>
          <div>
            <h4 class="text-yellow-200 font-semibold mb-2">Mixed Page Sizes Detected</h4>
            <p class="text-sm text-gray-300 mb-3">This document contains pages with different dimensions:</p>
            <ul class="space-y-1 text-sm text-gray-300">
              ${e.uniqueSizes.map(n=>`
                <li>• ${n.label}: ${n.count} page${n.count>1?"s":""}</li>
              `).join("")}
            </ul>
          </div>
        </div>
      </div>
    `),o.innerHTML=t,e.hasMixedSizes&&y({icons:v})}function b(o){const e=document.getElementById("dimensions-table-body");e&&(e.textContent="",l.forEach(t=>{const n=x(t.width,o),i=x(t.height,o),s=w(t.width,t.height),r=S(t.width,t.height,o),c=document.createElement("tr"),a=document.createElement("td");a.className="px-4 py-3 text-white",a.textContent=t.pageNum;const m=document.createElement("td");m.className="px-4 py-3 text-gray-300",m.textContent=`${n} x ${i} ${o}`;const u=document.createElement("td");u.className="px-4 py-3 text-gray-300",u.textContent=t.standardSize;const f=document.createElement("td");f.className="px-4 py-3 text-gray-300",f.textContent=t.orientation;const p=document.createElement("td");p.className="px-4 py-3 text-gray-300",p.textContent=s;const h=document.createElement("td");h.className="px-4 py-3 text-gray-300",h.textContent=r;const g=document.createElement("td");g.className="px-4 py-3 text-gray-300",g.textContent=`${t.rotation}°`,c.append(a,m,u,f,p,h,g),e.appendChild(c)}))}function P(){const e=document.getElementById("units-select")?.value||"pt",n=[["Page #",`Width (${e})`,`Height (${e})`,"Standard Size","Orientation","Aspect Ratio",`Area (${e}²)`,"Rotation"].join(",")];l.forEach(a=>{const m=x(a.width,e),u=x(a.height,e),f=w(a.width,a.height),p=S(a.width,a.height,e),h=[a.pageNum,m,u,a.standardSize,a.orientation,f,p,`${a.rotation}°`];n.push(h.join(","))});const i=n.join(`
`),s=new Blob([i],{type:"text/csv;charset=utf-8;"}),r=URL.createObjectURL(s),c=document.createElement("a");c.href=r,c.download="page-dimensions.csv",document.body.appendChild(c),c.click(),document.body.removeChild(c),URL.revokeObjectURL(r)}function N(){if(!d.pdfDoc)return;l=[],d.pdfDoc.getPages().forEach((i,s)=>{const{width:r,height:c}=i.getSize(),a=i.getRotation().angle||0;l.push({pageNum:s+1,width:r,height:c,orientation:r>c?"Landscape":"Portrait",standardSize:z(r,c),rotation:a})});const e=document.getElementById("dimensions-results"),t=document.getElementById("units-select");I(),b(t.value),e&&e.classList.remove("hidden"),t.addEventListener("change",i=>{b(i.target.value)});const n=document.getElementById("export-csv-btn");n&&n.addEventListener("click",P),y({icons:v})}function k(){d.file=null,d.pdfDoc=null,l=[];const o=document.getElementById("file-display-area");o&&(o.innerHTML="");const e=document.getElementById("dimensions-results");e&&e.classList.add("hidden");const t=document.getElementById("file-input");t&&(t.value="")}async function M(){const o=document.getElementById("file-display-area");if(o&&(o.innerHTML="",d.file)){const e=document.createElement("div");e.className="flex items-center justify-between bg-gray-700 p-3 rounded-lg text-sm";const t=document.createElement("div");t.className="flex flex-col overflow-hidden";const n=document.createElement("div");n.className="truncate font-medium text-gray-200 text-sm mb-1",n.textContent=d.file.name;const i=document.createElement("div");i.className="text-xs text-gray-400",i.textContent=L(d.file.size),t.append(n,i);const s=document.createElement("button");s.className="ml-4 text-red-400 hover:text-red-300 flex-shrink-0",s.innerHTML='<i data-lucide="trash-2" class="w-4 h-4"></i>',s.onclick=function(){k()},e.append(t,s),o.appendChild(e),y({icons:v})}}async function E(o){if(o&&o.length>0){const e=o[0];if(e.type==="application/pdf"||e.name.toLowerCase().endsWith(".pdf")){d.file=e;try{const t=await e.arrayBuffer();d.pdfDoc=await $.load(t),M(),N()}catch(t){console.error("Error loading PDF:",t),C("Error","Failed to load PDF file.")}}}}document.addEventListener("DOMContentLoaded",function(){const o=document.getElementById("file-input"),e=document.getElementById("drop-zone"),t=document.getElementById("back-to-tools");t&&t.addEventListener("click",function(){window.location.href="/"}),o&&e&&(o.addEventListener("change",function(n){E(n.target.files)}),e.addEventListener("dragover",function(n){n.preventDefault(),e.classList.add("bg-gray-700")}),e.addEventListener("dragleave",function(n){n.preventDefault(),e.classList.remove("bg-gray-700")}),e.addEventListener("drop",function(n){n.preventDefault(),e.classList.remove("bg-gray-700"),E(n.dataTransfer?.files)}),o.addEventListener("click",function(){o.value=""}))});
