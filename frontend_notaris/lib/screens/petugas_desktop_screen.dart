import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../database/app_database.dart';
import '../providers/people_provider.dart';

class PetugasDesktopScreen extends ConsumerStatefulWidget {
  const PetugasDesktopScreen({super.key});
  @override ConsumerState<PetugasDesktopScreen> createState()=>_PetugasDesktopScreenState();
}
class _PetugasDesktopScreenState extends ConsumerState<PetugasDesktopScreen>{
  final _search=TextEditingController(),_hScroll=ScrollController();
  static const _pageSize=5; int _page=1; bool _loading=false;

  @override Widget build(BuildContext context){
    final data=ref.watch(petugasProvider), genders=ref.watch(jenisKelaminProvider);
    return LoadingOverlay(isLoading:_loading,message:'Memproses data...',child:Padding(
      padding:const EdgeInsets.all(24),
      child:data.when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(e,_)=>Center(child:Text('Gagal memuat data: '+e.toString())),
        data:(items)=>genders.when(
          loading:()=>const Center(child:CircularProgressIndicator()),
          error:(e,_)=>Center(child:Text('Gagal memuat jenis kelamin: '+e.toString())),
          data:(gs)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _header(),const SizedBox(height:20),_table(items,gs)
          ]),
        ),
      ),
    ));
  }

  Widget _header()=>Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Petugas',style:TextStyle(fontSize:24,fontWeight:FontWeight.w700)),
      const SizedBox(height:4),Text('Master > Petugas',style:TextStyle(color:AppColors.textSecondary))
    ])),
    FilledButton.icon(onPressed:_showForm,style:FilledButton.styleFrom(backgroundColor:AppColors.primary,foregroundColor:Colors.white),icon:const Icon(Icons.add),label:const Text('Tambah'))
  ]);

  Widget _table(List<PetugasLocal> all,List<JenisKelamin> gs){
    final q=_search.text.trim().toLowerCase();
    final filtered=all.where((x)=>q.isEmpty||(x.nik??'').toLowerCase().contains(q)||x.nama.toLowerCase().contains(q)||_gender(x.jenisKelamin,gs).toLowerCase().contains(q)||x.email.toLowerCase().contains(q)||(x.noTelp??'').toLowerCase().contains(q)).toList();
    final pageCount=filtered.isEmpty?1:((filtered.length-1)~/_pageSize)+1;
    if(_page>pageCount)_page=pageCount;
    final start=(_page-1)*_pageSize, rows=filtered.skip(start).take(_pageSize).toList();
    return Card(color:AppColors.card,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:const BorderSide(color:AppColors.border)),child:Padding(
      padding:const EdgeInsets.all(18),child:Column(children:[
        Row(children:[Expanded(child:TextField(controller:_search,onChanged:(_)=>setState(()=>_page=1),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Cari NIK, nama, email, atau no telp...',border:OutlineInputBorder()))),const SizedBox(width:14),Text(filtered.length.toString()+' data')]),
        const SizedBox(height:16),
        Scrollbar(controller:_hScroll,thumbVisibility:true,child:SingleChildScrollView(controller:_hScroll,scrollDirection:Axis.horizontal,child:DataTable(
          columnSpacing:28,
          columns:const[DataColumn(label:Text('No')),DataColumn(label:Text('NIK')),DataColumn(label:Text('Nama')),DataColumn(label:Text('Jenis Kelamin')),DataColumn(label:Text('Email')),DataColumn(label:Text('No Telp')),DataColumn(label:Text('Created At')),DataColumn(label:Text('Aksi'))],
          rows:[for(var i=0;i<rows.length;i++)DataRow(cells:[
            DataCell(Text((start+i+1).toString())),DataCell(Text(rows[i].nik??'-')),DataCell(Text(rows[i].nama)),DataCell(Text(_gender(rows[i].jenisKelamin,gs))),DataCell(Text(rows[i].email)),DataCell(Text(rows[i].noTelp??'-')),DataCell(Text(_dateTime(rows[i].createdAt))),
            DataCell(Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'Edit',onPressed:()=>_showForm(item:rows[i]),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Hapus',onPressed:()=>_delete(rows[i]),icon:const Icon(Icons.delete_outline))]))
          ])]
        )))),
        if(rows.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('Belum ada data petugas.')),
        const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.end,children:[
          IconButton(onPressed:_page>1?()=>setState(()=>_page--):null,icon:const Icon(Icons.chevron_left)),
          Text('Halaman '+_page.toString()+' / '+pageCount.toString()),
          IconButton(onPressed:_page<pageCount?()=>setState(()=>_page++):null,icon:const Icon(Icons.chevron_right))
        ])
      ])
    ));
  }

  void _showForm({PetugasLocal? item}){
    final nik=TextEditingController(text:item?.nik??''),nama=TextEditingController(text:item?.nama??''),tempat=TextEditingController(text:item?.tempatLahir??''),telp=TextEditingController(text:item?.noTelp??''),email=TextEditingController(text:item?.email??''),alamat=TextEditingController(text:item?.alamat??''),userId=TextEditingController(text:item?.userId?.toString()??'');
    DateTime? tanggal=item?.tanggalLahir; int? genderId=item?.jenisKelamin;
    final gs=ref.read(jenisKelaminProvider).valueOrNull??<JenisKelamin>[];
    showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setDialogState)=>AlertDialog(
      title:Text(item==null?'Tambah Petugas':'Edit Petugas'),
      content:SizedBox(width:760,child:SingleChildScrollView(child:Column(children:[
        _row(_field('NIK',nik,type:TextInputType.number),_field('Nama *',nama)),const SizedBox(height:12),
        _row(SearchableDropdown<JenisKelamin>(label:'Jenis Kelamin',hint:'Pilih jenis kelamin',value:_genderObject(genderId,gs),items:gs,itemLabel:(x)=>x.nama,onChanged:(v)=>setDialogState(()=>genderId=v?.id)),_field('Tempat Lahir',tempat)),const SizedBox(height:12),
        _row(_dateField(tanggal,(v)=>setDialogState(()=>tanggal=v)),_field('Telp',telp,type:TextInputType.phone)),const SizedBox(height:12),
        _row(_field('Email *',email,type:TextInputType.emailAddress),_field('User ID',userId,type:TextInputType.number,helper:'Opsional. Master User belum tersedia di SQLite.')),const SizedBox(height:12),
        _field('Alamat',alamat,maxLines:4)
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Batal')),
        FilledButton.icon(onPressed:()async{
          if(nama.text.trim().isEmpty||email.text.trim().isEmpty){_message('Nama dan email wajib diisi.');return;}
          setState(()=>_loading=true);
          try{
            final c=ref.read(petugasControllerProvider.notifier),uid=int.tryParse(userId.text.trim());
            if(item==null){await c.create(nama:nama.text,nik:nik.text,alamat:alamat.text,tempatLahir:tempat.text,tanggalLahir:tanggal,jenisKelamin:genderId,noTelp:telp.text,email:email.text,userId:uid);}
            else{final ok=await c.updatePetugas(id:item.id,nama:nama.text,nik:nik.text,alamat:alamat.text,tempatLahir:tempat.text,tanggalLahir:tanggal,jenisKelamin:genderId,noTelp:telp.text,email:email.text,userId:uid);if(!ok)throw StateError('Petugas tidak ditemukan.');}
            if(dialogContext.mounted)Navigator.pop(dialogContext);_message(item==null?'Petugas berhasil ditambahkan.':'Petugas berhasil diperbarui.');
          }catch(e){_message('Gagal menyimpan petugas: '+e.toString());}finally{if(mounted)setState(()=>_loading=false);}
        },icon:const Icon(Icons.save_outlined),label:const Text('Simpan'))
      ]
    ))).whenComplete(()=>[nik,nama,tempat,telp,email,alamat,userId].forEach((c)=>c.dispose()));
  }

  Widget _row(Widget a,Widget b)=>LayoutBuilder(builder:(context,c)=>c.maxWidth<560?Column(children:[a,const SizedBox(height:12),b]):Row(children:[Expanded(child:a),const SizedBox(width:12),Expanded(child:b)]));
  Widget _field(String label,TextEditingController c,{TextInputType? type,int maxLines=1,String? helper})=>TextField(controller:c,keyboardType:type,maxLines:maxLines,decoration:InputDecoration(labelText:label,helperText:helper,border:const OutlineInputBorder()));
  Widget _dateField(DateTime? value,ValueChanged<DateTime?> onChanged)=>InkWell(
    onTap:()async{final picked=await showDatePicker(context:context,initialDate:value??DateTime(2000),firstDate:DateTime(1900),lastDate:DateTime.now());if(picked!=null)onChanged(picked);},
    child:InputDecorator(decoration:const InputDecoration(labelText:'Tanggal Lahir',border:OutlineInputBorder(),suffixIcon:Icon(Icons.calendar_today_outlined)),child:Text(value==null?'Pilih tanggal':_date(value)))
  );

  Future<void> _delete(PetugasLocal item)async{
    final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Hapus Petugas'),content:Text('Hapus petugas "'+item.nama+'"? Data akan di-soft delete.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Hapus'))]));
    if(yes!=true)return;setState(()=>_loading=true);
    try{final ok=await ref.read(petugasControllerProvider.notifier).delete(item.id);_message(ok?'Petugas berhasil dihapus.':'Petugas tidak ditemukan.');}catch(e){_message('Gagal menghapus petugas: '+e.toString());}finally{if(mounted)setState(()=>_loading=false);}
  }

  void _message(String text){ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content:Text(text)));}
  static JenisKelamin? _genderObject(int? id,List<JenisKelamin> items){for(final x in items){if(x.id==id)return x;}return null;}
  static String _gender(int? id,List<JenisKelamin> items)=>_genderObject(id,items)?.nama??'-';
  static String _date(DateTime d)=>d.day.toString().padLeft(2,'0')+'/'+d.month.toString().padLeft(2,'0')+'/'+d.year.toString();
  static String _dateTime(DateTime? d)=>d==null?'-':_date(d)+' '+d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
  @override void dispose(){_search.dispose();_hScroll.dispose();super.dispose();}
}
